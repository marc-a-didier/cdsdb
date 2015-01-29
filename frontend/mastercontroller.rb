
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

    include GtkIDs

    attr_reader   :player, :pqueue, :plists, :charts, :tasks, :filters, :memos
    attr_accessor :main_filter, :filter_receiver

    def initialize
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

        XIntf::Image::Cache.preload_tracks_cover
    end

    #
    # Save windows positions, windows states and clean up the client music cache
    #
    def clean_up
        @player.terminate

        [VIEW_MENU, MM_WIN_MENU, MM_EDIT_MENU, MM_PLAYER_MENU, MM_PLAYER_SRC].each { |menu| Prefs.save_menu_state(GtkUI[menu]) }

        Prefs.save_windows([MAIN_WINDOW, PLISTS_WINDOW, PLAYER_WINDOW, PQUEUE_WINDOW,
                            CHARTS_WINDOW, FILTER_WINDOW, TASKS_WINDOW, MEMOS_WINDOW])

        Cfg.save
    end

    #
    # Set the check item to false to really close the window
    #
    def notify_closed(window)
        GtkUI[MM_WIN_PLAYER].active = false if window == @player
        GtkUI[MM_WIN_PLAYQUEUE].active = false if window == @pqueue
        GtkUI[MM_WIN_PLAYLISTS].active = false if window == @plists
        GtkUI[MM_WIN_CHARTS].active = false if window == @charts
        GtkUI[MM_WIN_FILTER].active = false if window == @filters
        GtkUI[MM_WIN_TASKS].active = false if window == @tasks
        GtkUI[MM_WIN_MEMOS].active = false if window == @memos

        @player.unfetch(window) if window == @pqueue || window == @plists
    end

    def reset_filter_receiver
        @filter_receiver = @mw # A revoir s'y a une aute fenetre censee recevoir le focus
    end

    def show_segment_title?
        return GtkUI[MM_VIEW_SEGTITLE].active?
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

    def track_xlink;         @mw.trk_browser.trklnk;                   end


    def invalidate_tabs
        return if @mw.nil? # Required on fedora at startup
        @mw.rec_browser.invalidate
        @mw.trk_browser.invalidate
    end

    def sub_filter
        return @mw.art_browser.sub_filter
    end

    def view_compile?
        return GtkUI[MM_VIEW_COMPILE].active?
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

    def audio_link_ok(xlink)
        @mw.trk_browser.audio_link_ok(xlink)
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

    def get_track_xlink(track_index)
        return @mw.trk_browser.get_track_xlink(track_index)
    end

    def notify_played(xlink, host = "")
        # If rtrack is -1 the track has been dropped into the pq from the file system
        return if xlink.track.rtrack == -1 # || xlink.track.banned?

        host = Socket.gethostname if host.empty?

        DBUtils.update_track_stats(xlink.track.rtrack, host)

        # Update gui if the played track is currently selected.
        # Dangerous if user is modifying the track panel!!!
        xlink.reload_track_cache
        @mw.trk_browser.update_infos

        Thread.new {
            @mw.set_window_title

            @charts.live_update(xlink) if Cfg.live_charts_update? && @charts.window.visible?

            MusicClient.update_stats(xlink.track.rtrack) if Cfg.remote?
        }

        # if GtkUI[UIConsts::MM_VIEW_UPDATENP].active?
        #     if @rec_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
        #         @art_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
        #     end
        # end
    end


    def select_artist(rartist, force_reload = false)
        if !@mw.art_browser.artlnk.valid_track_ref? || self.artist.rartist != rartist || force_reload
            @mw.art_browser.select_artist(rartist)
        end
    end

    def select_record(xlink, force_reload = false)
        # Check if show the compilations artist if grouped
        if xlink.record.rartist == 0 && !view_compile? && xlink.valid_segment_ref?
            rartist = xlink.segment.rartist
        else
            rartist = xlink.record.rartist
        end
        select_artist(rartist)
        if !@mw.rec_browser.reclnk.valid_record_ref? || self.record.rrecord != xlink.record.rrecord || force_reload
            @mw.rec_browser.select_record(xlink.record.rrecord)
        end
    end

    def select_segment(xlink, force_reload = false)
        xlink.set_record_ref(xlink.segment.rrecord)
        select_record(xlink)
        @mw.rec_browser.select_segment_from_record_selection(xlink.segment.rsegment) # if self.segment.rsegment != rsegment || force_reload
    end

    def select_track(xlink, force_reload = false)
        select_record(xlink)
        if !@mw.trk_browser.trklnk.valid_track_ref? || self.track.rtrack != xlink.track.rtrack || force_reload
            @mw.trk_browser.position_to(xlink.track.rtrack)
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
        # Check if provider REALLY changed. It may have changed from Automatic to Play queue
        # and in this case, there's nothing to do.
        if src_window != track_provider
            # Remove tracks from the queue of previous provider
            @player.unfetch(track_provider)
            # Set new provider and refetch player from it
            @player_src = src_window
            @player.refetch(track_provider)
        end
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
end
