
# This module defines all the methods that a player provider should respond to

module PlayerIntf

    TrackRefs = Struct.new(:owner, :internal_ref, :xlink, :rplist)

    # Emitted every half second for the provider do whatever it wants
    def timer_notification(ms_time)
        return self
    end

    # Called when a track has started playing
    def started_playing(player_data)
        return self
    end

    # Called when a track is finished.
    # message is the type of termination. may be :stop, :finish or :next
    def notify_played(player_data, message)
        return self
    end

    # Should append max_entries tracks to queue
    def prefetch_tracks(queue, max_entries)
        return self
    end

    # Called via master conntroller to get a track to play
    # direction may be :start, :next or :prev
    # :start is used to get the first track when the play button is pressed
    # :next is never used as the player has a prefetch queue
    # :prev is used to get the previous track
    def get_track(player_data, direction)
        return nil
    end

    # Should return true if provider has more tracks to play
    # direction is either :next or :prev
    # Should return true or false if it has or not a track in the wanted direction
    def has_track(player_data, direction)
        return false
    end


    # This module implements PlayerIntf methods for track providers based upon a treeview,
    # the tracks browser and play list browser for instance.
    # It overides has_track & notify_played, the other methods need more parameters

    module Browser

        # Sets the track reference and positions the browser cursor on it.
        def do_started_playing(tv, player_data)
            return if @track_ref == -1 # if @track_ref is -1, the track list has changed, so leave
            @track_ref = player_data.internal_ref
            iter = tv.model.get_iter(player_data.internal_ref.to_s)
            tv.set_cursor(iter.path, nil, false)
        end

        # Prefetch modus operandi:
        # - search for n tracks to add to the queue
        # - if a track is on server start download of this track but NOT added to the queue:
        #   the download notification will call the player refetch. As long as tracks are
        #   downloading the queue size doesn't change.
        #   If tracks are already on disk after the downloaded tracks, these tracks will
        #   be queued and removed if downloads are finished before they are started.
        # - If all tracks are on server, there may be one more track download than expected
        #   while queue is not not full.
        def do_prefetch_tracks(model, link_index, queue, max_entries)
            downloads_count = 0
            entry = queue.last.internal_ref+1
            max_downloads = max_entries+1 - queue.size
            while queue.size < max_entries+1 # queue has at least the [0] element -> +1
                iter = model.get_iter(entry.to_s)
                break if iter.nil? # Reached the end of the tracks

                iter[link_index].setup_audio_file
                if iter[link_index].playable? # OK or MISPLACED
                    queue << TrackRefs.new(self, entry, iter[link_index])
                else
                    # Track not available, check to see if not already in download tasks
                    if @mc.tasks.track_in_download?(iter[link_index])
                        downloads_count += 1
                    else
                        # If available on server and max downlaods not reached, start a task
                        if downloads_count < max_downloads && iter[link_index].available_on_server?
                            iter[link_index].get_remote_audio_file(TasksWindow::Task.new(:download, :track, iter[link_index], self), @mc.tasks)
                            downloads_count += 1
                        end
                    end
                end
                entry += 1
            end
        end

        # Returns the TrackRefs corresponnding to the message.
        # If message is start, returns the first track to be played. If track is on
        # server, the player must wait for it to be downloaded.
        # If message is :next or :prev, it's a lookup. If nil is returned, there are no
        # more tracks to be played in that direction. nil is also returned if there are tracks
        # but on server.
        def do_get_track(tv, link_index, player_data, direction)
            if direction == :start
                @track_ref = tv.cursor.nil? ? 0 : tv.cursor[0].to_s.to_i
                return get_audio_file(tv, link_index)
            else
                offset = direction == :next ? +1 : -1
                index = 0
                loop do
                    index += offset
                    return nil if player_data.internal_ref+index < 0
                    iter = tv.model.get_iter((player_data.internal_ref+index).to_s)
                    return nil if iter.nil?
                    iter[link_index].setup_audio_file if iter[link_index].audio_status == Audio::Status::UNKNOWN
                    return TrackRefs.new(self, iter.path.to_s.to_i, iter[link_index]) if iter[link_index].playable?
                end
            end
        end

        # Overrides PlayerIntf version
        def has_track(player_data, direction)
            return !get_track(player_data, direction).nil?
        end

        # Overrides PlayerIntf version
        def notify_played(player_data, message)
            reset_player_data_state unless message == :next || message == :prev # :prev is never used...
        end

        # Method to get the first track to played up and ready
        # If it's available on server, keep waiting until it's downloaded
        def get_audio_file(tv, link_index)
            while true
                iter = tv.model.get_iter(@track_ref.to_s)
                if iter.nil?
                    reset_player_data_state
                    return nil
                end

                tv.set_cursor(iter.path, nil, false)
                if iter[link_index].get_audio_file(TasksWindow::Task.new(:download, :track, iter[link_index], self), @mc.tasks) == Audio::Status::NOT_FOUND
                    @track_ref += 1
                else
                    break
                end
            end

            while iter[link_index].audio_status == Audio::Status::ON_SERVER
                Gtk.main_iteration while Gtk.events_pending?
                sleep(0.1)
            end

            return TrackRefs.new(self, @track_ref, iter[link_index])
        end
    end
end
