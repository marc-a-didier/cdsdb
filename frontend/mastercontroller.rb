
#
#
# The master controller class is responsible for handling events from the main menu.
#
# It defers the execution of events to the treeviews when possible doing it itself otherwise.
#
# It passes itself as parameter to the treeviews and permanent windows giving them
# access to needed attributes, mainly glade and main_filter.
#
# It has messages to get the reference to each browser current selection thus acting
# as a pivot for inter-browser dialogs.
#
#

class MasterController

    include UIConsts

    attr_reader   :glade
    attr_reader   :player, :pqueue, :plists, :charts, :tasks, :filters, :memos
    attr_accessor :main_filter, :filter_receiver

    def initialize
        @glade = GTBld.main


        # SQL AND/OR clause reflecting the filter settings that must be appended to the sql requests
        # if view is filtered
        @main_filter = ""

        @player_src = nil

        #
        # Create never destroyed windows
        #
        @pqueue   = PQueueWindow.new(self)
        @player   = PlayerWindow.new(self)
        @plists   = PListsWindow.new(self)
        @charts   = ChartsWindow.new(self)
        @tasks    = TasksWindow.new(self)
        @filters  = FilterWindow.new(self)
        @memos    = MemosWindow.new(self)

        @mw = MainWindow.new(self)
    end

    #
    # Save windows positions, windows states and clean up the client music cache
    #
    def clean_up
        @player.stop if @player.playing? || @player.paused?
        [VIEW_MENU, MM_WIN_MENU, MM_EDIT_MENU, MM_PLAYER_MENU, MM_PLAYER_SRC].each { |menu| PREFS.save_menu_state(self, @glade[menu]) }
#         [@mw, @plists, @player, @pqueue, @charts, @filters, @tasks, @memos].each { |tw| tw.hide if tw.window.visible? }
        PREFS.save_windows([@mw, @plists, @player, @pqueue, @charts, @filters, @tasks, @memos])
        #system("rm -f ../mfiles/*")
        CFG.save
    end

    #
    # Set the check item to false to really close the window
    #
    def notify_closed(window)
        @glade[MM_WIN_PLAYER].active = false if window == @player
        @glade[MM_WIN_PLAYQUEUE].active = false if window == @pqueue
        @glade[MM_WIN_PLAYLISTS].active = false if window == @plists
        @glade[MM_WIN_CHARTS].active = false if window == @charts
        @glade[MM_WIN_FILTER].active = false if window == @filters
        @glade[MM_WIN_TASKS].active = false if window == @tasks
        @glade[MM_WIN_MEMOS].active = false if window == @memos

        @player.provider_may_have_changed(window) if window == @pqueue || window == @plists
    end

    def reset_filter_receiver
        @filter_receiver = @mw # A revoir s'y a une aute fenetre censee recevoir le focus
    end

    def show_segment_title?
        return @glade[MM_VIEW_SEGTITLE].active?
    end

    def history_closed(sender)
        @mw.history_closed(sender)
    end

    def update_tags_menu(pm_owner, menu_item)
        @mw.update_tags_menu(pm_owner, menu_item)
    end


    #
    # The following methods allow the browsers to get informations about the current
    # selection of the other browsers and notify the mc when a selection has changed.
    #
    def artist;              @mw.art_browser.artlnk.artist             end
    def record;              @mw.rec_browser.reclnk.record             end
    def segment;             @mw.rec_browser.reclnk.segment            end
    def track;               @mw.trk_browser.trklnk.track              end
    def artist_changed;      @mw.rec_browser.load_entries_select_first end
    def record_changed;      @mw.trk_browser.load_entries_select_first end
    def is_on_record;        @mw.rec_browser.is_on_record              end
    def is_on_never_played?; @mw.art_browser.is_on_never_played?       end
    def is_on_compilations?; @mw.art_browser.is_on_compile?            end

    def invalidate_tabs
        return if @mw.nil? # Required on fedora at startup
        @mw.rec_browser.invalidate
        @mw.trk_browser.invalidate
    end

    def sub_filter
        return @mw.art_browser.sub_filter
    end

    def view_compile?
        return @glade[MM_VIEW_COMPILE].active?
    end

    # Update the artist browser infos line from rartist data
    def update_artist_infos(rartist)
        @mw.art_browser.update_segment_artist(rartist)
    end

    # Called when browsing tracks from compilations to keep artist and segment synched
    # Updates the track's artist infos
    def set_segment_artist(dblink)
        @mw.rec_browser.set_segment_from_track(dblink.track.rsegment)
        update_artist_infos(dblink.segment.rartist)
    end

    def no_selection
        @mw.trk_browser.clear
        @mw.rec_browser.clear
    end

    def audio_link_ok(uilink)
        @mw.trk_browser.audio_link_ok(uilink)
    end


    def reload_plists
        @plists.reload
        return self
    end

    def reload_filters
        @filters.load_ftv
        return self
    end


    def enqueue_record
        @pqueue.enqueue(@mw.trk_browser.get_tracks_list)
    end

    def download_tracks
        @mw.trk_browser.download_tracks(false)
    end

    def get_tracks_list # Returns all visible tracks
        return @mw.trk_browser.get_tracks_list
    end

    def get_tracks_selection # Returns only selected tracks
        return @mw.trk_browser.get_selection
    end

    def get_plist_selection
        return @plists.get_selection
    end

    def get_pqueue_selection
        return @pqueue.get_selection
    end

    # Only selection message with parameter to know from which kind of history we deal with
    def get_history_selection(param)
        return @mw.history[param].get_selection
    end

    def get_charts_selection
        return @charts.get_selection
    end

    def get_search_selection
        return @mw.search_dlg.get_selection
    end

    def get_track_uilink(track_index)
        return @mw.trk_browser.get_track_uilink(track_index)
    end

    def notify_played(uilink, host = "")
        # If rtrack is -1 the track has been dropped into the pq from the file system
        return if uilink.track.rtrack == -1 || uilink.track.banned?

        host = Socket.gethostname if host.empty?

        DBUtils.update_track_stats(uilink.track.rtrack, host)

        # Update gui if the played track is currently selected.
        # Dangerous if user is modifying the track panel!!!
        uilink.reload_track_cache
        @mw.trk_browser.update_infos

        Thread.new {
            @charts.live_update(uilink) if CFG.live_charts_update? && @charts.window.visible?

            MusicClient.new.update_stats(uilink.track.rtrack) if CFG.remote?
        }

#         if @glade[UIConsts::MM_VIEW_UPDATENP].active?
#             if @rec_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
#                 @art_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
#             end
#         end
    end


    def select_artist(rartist, force_reload = false)
        if !@mw.art_browser.artlnk.valid? || self.artist.rartist != rartist || force_reload
            @mw.art_browser.select_artist(rartist)
        end
    end

    def select_record(uilink, force_reload = false)
        # Check if show the compilations artist if grouped
        if uilink.record.rartist == 0 && !view_compile? && uilink.valid_segment_ref?
            rartist = uilink.segment.rartist
        else
            rartist = uilink.record.rartist
        end
        select_artist(rartist)
        if !@mw.rec_browser.reclnk.valid? || self.record.rrecord != uilink.record.rrecord || force_reload
            @mw.rec_browser.select_record(uilink.record.rrecord)
        end
    end

    def select_segment(uilink, force_reload = false)
        uilink.set_record_ref(uilink.segment.rrecord)
        select_record(uilink)
        @mw.rec_browser.select_segment_from_record_selection(uilink.segment.rsegment) # if self.segment.rsegment != rsegment || force_reload
    end

    def select_track(uilink, force_reload = false)
        select_record(uilink)
        if !@mw.trk_browser.trklnk.valid? || self.track.rtrack != uilink.track.rtrack || force_reload
            @mw.trk_browser.position_to(uilink.track.rtrack)
        end
    end

    #
    # Messages sent by the player to get a track provider
    #
    def track_provider
        return @player_src if @player_src
        return @pqueue if @pqueue.window.visible?
        return @plists if @plists.window.visible?
        return @mw.trk_browser
    end

    def set_player_source(src_window)
puts("set player source called") #, active = #{widget.active?}")
        @player_src = src_window
        @player.refetch(track_provider)
#         track_list_changed(track_provider)
#         @player.provider_may_have_changed(track_provider)
    end

    # Called by the player to get the first track to from the provider
    def get_track(player_data, direction)
        return track_provider.get_track(player_data, direction)
    end

    # Called by providers when something may have changed in the play order
    def track_list_changed(sender)
        @player.refetch(sender)
    end

    # Called by the play list/browser when it's the provider and user moved to another play list/record
    # In this case, erase the next tracks without providing any new one
    def unfetch_player(sender)
        @player.unfetch(sender)
    end

    # Play list specific call to handle the mess of changing the play list while playing
#     def is_current_provider(track_provider)
#         return @player.is_current_provider(track_provider)
#     end
#
#     def is_next_provider(track_provider)
#         return @player.is_next_provider(track_provider)
#     end
end
