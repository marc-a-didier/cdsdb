
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

    attr_reader   :glade, :main_filter
    attr_reader   :player, :pqueue, :plists, :charts, :tasks, :filter, :memos
    attr_accessor :filter_receiver

    def initialize
        @glade = GTBld.main


        # SQL AND/OR clause reflecting the filter settings that must be appended to the sql requests
        # if view is filtered
        @main_filter = ""

        #
        # Create never destroyed windows
        #
        @pqueue   = PQueueWindow.new(self)
        @player   = PlayerWindow.new(self)
        @plists   = PListsWindow.new(self)
        @charts   = ChartsWindow.new(self)
        @tasks    = TasksWindow.new(self)
        @filter   = FilterWindow.new(self)
        @memos    = MemosWindow.new(self)

        @mw = MainWindow.new(self)
    end

    #
    # Save windows positions, windows states and clean up the client music cache
    #
    def clean_up
        @player.stop if @player.playing? || @player.paused?
#         PREFS.save_window(@glade[MAIN_WINDOW])
        PREFS.save_menu_state(self, @glade[VIEW_MENU])
        PREFS.save_menu_state(self, @glade[MM_WIN_MENU])
        [@plists, @player, @pqueue, @charts, @filter, @tasks, @memos].each { |tw|
            tw.hide if tw.window.visible?
        }
        #system("rm -f ../mfiles/*")
    end

    #
    # Set the check item to false to really close the window
    #
    def notify_closed(window)
        @glade[MM_WIN_PLAYER].active = false if window == @player
        @glade[MM_WIN_PLAYQUEUE].active = false if window == @pqueue
        @glade[MM_WIN_PLAYLISTS].active = false if window == @plists
        @glade[MM_WIN_CHARTS].active = false if window == @charts
        @glade[MM_WIN_FILTER].active = false if window == @filter
        @glade[MM_WIN_TASKS].active = false if window == @tasks
        @glade[MM_WIN_MEMOS].active = false if window == @memos
    end

    def reset_filter_receiver
        @filter_receiver = @mw # A revoir s'y a une aute fenetre censee recevoir le focus
    end

    def show_segment_title?
        return @glade[MM_VIEW_SEGTITLE].active?
    end

    def recent_items_closed(sender)
        @mw.recent_items_closed(sender)
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
        @mw.rec_browser.invalidate
        @mw.trk_browser.invalidate
    end

    def new_link_from_selection
        return DBCacheLink.new.set_artist_ref(record.compile? ? segment.rartist : artist.rartist) \
                              .set_record_ref(record.rrecord) \
                              .set_segment_ref(segment.rsegment) \
                              .set_track_ref(track.rtrack)
    end

    def sub_filter
        return @mw.art_browser.sub_filter
    end

    def view_compile?
        return @glade[MM_VIEW_COMPILE].active?
    end

    # Called when browsing compilations to display the current artist infos
    def change_segment_artist(rartist)
        @mw.art_browser.update_segment_artist(rartist)
    end

    def no_selection
        @mw.trk_browser.clear
        @mw.rec_browser.clear
    end

    def audio_link_ok(uilink)
        @mw.trk_browser.audio_link_ok(uilink)
    end

    #
    # Filter management
    #
    def set_filter(where_clause, must_join_logtracks)
        if (where_clause != @main_filter)
            uilink = @mw.trk_browser.trklnk
            @main_filter = where_clause
            @mw.art_browser.reload
            select_track(uilink) if uilink
        end
    end

    def reload_plists
        @plists.reload
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

    # Only selection message with parameter to know from which recent items we deal with
    def get_recent_selection(param)
        return @mw.recents[param].get_selection
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

        Thread.new {
            # Update local database AND remote database if in client mode
            host = Socket::gethostname if host == ""

            DBUtils::update_track_stats(uilink.track.rtrack, host)

            # Update gui if the played track is currently selected. Dangerous if user is modifying the track panel!!!
            @mw.trk_browser.update_infos(uilink.reload_track_cache.track.rtrack)

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
    def get_next_track(is_next)
        meth = is_next ? :get_next_track : :get_prev_track
        return @pqueue.send(meth) if @pqueue.window.visible?
        return @plists.send(meth) if @plists.window.visible?
        return @mw.trk_browser.send(meth)
    end

end
