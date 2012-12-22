
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

    attr_reader   :glade, :plists, :pqueue, :tasks, :filter, :main_filter
    attr_accessor :filter_receiver


    RECENT_ADDED  = 0
    RECENT_RIPPED = 1
    RECENT_PLAYED = 2

    def initialize(path_or_data, root, domain)
        @glade = GTBld.main


        @st_icon = Gtk::StatusIcon.new
        @st_icon.stock = Gtk::Stock::CDROM
        if @st_icon.respond_to?(:has_tooltip=) # To keep compat with gtk2 < 2.16
            @st_icon.has_tooltip = true
            @st_icon.signal_connect(:query_tooltip) { |si, x, y, is_kbd, tool_tip|
                @player.playing? ? @player.show_tooltip(si, tool_tip) :
                                   tool_tip.set_markup("\n<b>CDs DB: waiting for tracks to play...</b>\n")
                true
            }
        end
        @st_icon.signal_connect(:popup_menu) { |tray, button, time|
            @glade[UIConsts::TTPM_MENU].popup(nil, nil, button, time) { |menu, x, y, push_in| @st_icon.position_menu(menu) }
        }

        # SQL AND/OR clause reflecting the filter settings that must be appended to the sql requests
        # if view is filtered
        @main_filter = ""

        # Var de merde pour savoir d'ou on a clique pour avoir le popup contenant tags ou rating
        # L'owner est donc forcement le treeview des records ou celui des tracks
        # ... En attendant de trouver un truc plus elegant
        @pm_owner = nil


        # Set cd image to default image
        @glade[UIConsts::REC_IMAGE].pixbuf = ImageCache::instance.default_large_record
        ImageCache.instance.preload_tracks_cover

        Gtk::IconTheme.add_builtin_icon("player_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"player.png"))
        Gtk::IconTheme.add_builtin_icon("pqueue_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"pqueue.png"))
        Gtk::IconTheme.add_builtin_icon("plists_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"plists.png"))
        Gtk::IconTheme.add_builtin_icon("charts_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"charts.png"))
        @glade[UIConsts::MW_TBBTN_PLAYER].icon_name = "player_icon"
        @glade[UIConsts::MW_TBBTN_PQUEUE].icon_name = "pqueue_icon"
        @glade[UIConsts::MW_TBBTN_PLISTS].icon_name = "plists_icon"
        @glade[UIConsts::MW_TBBTN_CHARTS].icon_name = "charts_icon"

        Gtk::IconTheme.add_builtin_icon("information_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"information.png"))
        Gtk::IconTheme.add_builtin_icon("tasks_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"tasks.png"))
        Gtk::IconTheme.add_builtin_icon("filter_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"filter.png"))
        Gtk::IconTheme.add_builtin_icon("memos_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"document-edit.png"))

        @glade[UIConsts::MW_TBBTN_APPFILTER].icon_name  = "information_icon"
        @glade[UIConsts::MW_TBBTN_TASKS].icon_name  = "tasks_icon"
        @glade[UIConsts::MW_TBBTN_FILTER].icon_name = "filter_icon"
        @glade[UIConsts::MW_TBBTN_MEMOS].icon_name  = "memos_icon"


        # Connect signals needed to restore windows positions
        @glade[UIConsts::MW_PLAYER_ACTION].signal_connect(:activate) { toggle_window_visibility(@player) }
        @glade[UIConsts::MW_PQUEUE_ACTION].signal_connect(:activate) { toggle_window_visibility(@pqueue) }
        @glade[UIConsts::MW_PLISTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@plists) }
        @glade[UIConsts::MW_CHARTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@charts) }
        @glade[UIConsts::MW_TASKS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@tasks ) }
        @glade[UIConsts::MW_FILTER_ACTION].signal_connect(:activate) { toggle_window_visibility(@filter) }
        @glade[UIConsts::MW_MEMOS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@memos)  }

        # Action called from the memos window, equivalent to File/Save of the main window
        @glade[UIConsts::MW_MEMO_SAVE_ACTION].signal_connect(:activate) { on_save_item  }

        # Load view menu before instantiating windows (plists case)
        Prefs::instance.load_menu_state(self, @glade[UIConsts::VIEW_MENU])

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

        # Stores the recent items window object
        @recents = [nil, nil, nil] # Pointer to recent added/ripped/played
        @search_dlg   = nil

        # Set windows icons
        @pqueue.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"pqueue.png")
        @player.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"player.png")
        @plists.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"plists.png")
        @charts.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"charts.png")
        @tasks.window.icon  = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"tasks.png")
        @filter.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"filter.png")
        @memos.window.icon  = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"document-edit.png")

        # Reload windows state from the last session BEFORE connecting signals
        Prefs::instance.load_menu_state(self, @glade[UIConsts::MM_WIN_MENU])


        #
        # Toute la plomberie incombant au master controller...
        #
        @glade[UIConsts::MM_FILE_CHECKCD].signal_connect(:activate)     { CDEditorWindow.new.edit_record }
        @glade[UIConsts::MM_FILE_IMPORTSQL].signal_connect(:activate)   { import_sql_file }
        @glade[UIConsts::MM_FILE_IMPORTAUDIO].signal_connect(:activate) { on_import_audio_file }
        #@glade[UIConsts::MM_FILE_SAVE].signal_connect(:activate)        { on_save_item }
        @glade[UIConsts::MM_FILE_QUIT].signal_connect(:activate)        { clean_up; Gtk.main_quit }

        @glade[UIConsts::MM_EDIT_SEARCH].signal_connect(:activate)      { @search_dlg = SearchDialog.new(self).run }
        @glade[UIConsts::MM_EDIT_PREFS].signal_connect(:activate)       { PrefsDialog.new.run; @tasks.check_config }


        @glade[UIConsts::MM_VIEW_BYRATING].signal_connect(:activate) { record_changed   }
        @glade[UIConsts::MM_VIEW_COMPILE].signal_connect(:activate)  { change_view_mode }
        @glade[UIConsts::MM_VIEW_DBREFS].signal_connect(:activate)   { set_dbrefs_visibility }

        # Faudra revoir, on peut ouvrir plusieurs fenetre des recent items en meme temps...
        @glade[UIConsts::MM_WIN_RECENT].signal_connect(:activate) { handle_recent_items(RECENT_ADDED)  }
        @glade[UIConsts::MM_WIN_RIPPED].signal_connect(:activate) { handle_recent_items(RECENT_RIPPED) }
        @glade[UIConsts::MM_WIN_PLAYED].signal_connect(:activate) { handle_recent_items(RECENT_PLAYED) }

        @glade[UIConsts::MM_TOOLS_SEARCH_ORPHANS].signal_connect(:activate)     {
            Utils::search_for_orphans(UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER) {
                Gtk.main_iteration while Gtk.events_pending?
            } )
        }
        @glade[UIConsts::MM_TOOLS_TAG_GENRE].signal_connect(:activate)          { on_tag_dir_genre }
        @glade[UIConsts::MM_TOOLS_SCANAUDIO].signal_connect(:activate)          { Utils::scan_for_audio_files(@glade["main_window"]) }
        @glade[UIConsts::MM_TOOLS_IMPORTPLAYEDTRACKS].signal_connect(:activate) { UIUtils::import_played_tracks }
        @glade[UIConsts::MM_TOOLS_SYNCSRC].signal_connect(:activate)            { on_update_sources }
        @glade[UIConsts::MM_TOOLS_SYNCDB].signal_connect(:activate)             { on_update_db }
        @glade[UIConsts::MM_TOOLS_SYNCRES].signal_connect(:activate)            { on_update_resources }
        @glade[UIConsts::MM_TOOLS_EXPORTDB].signal_connect(:activate)           { Utils::export_to_xml }
        @glade[UIConsts::MM_TOOLS_GENREORDER].signal_connect(:activate)         { DBReorderer.new.run }
        @glade[UIConsts::MM_TOOLS_RATINGSTEST].signal_connect(:activate)        { Utils::test_ratings }
        @glade[UIConsts::MM_TOOLS_STATS].signal_connect(:activate)              { Stats.new(self).db_stats }

        @glade[UIConsts::MM_ABOUT].signal_connect(:activate) { Credits::show_credits }

        @glade[UIConsts::REC_VP_IMAGE].signal_connect("button_press_event") { zoom_rec_image }

        @glade[UIConsts::MAIN_WINDOW].signal_connect(:destroy)      { Gtk.main_quit }
        @glade[UIConsts::MAIN_WINDOW].signal_connect(:delete_event) { clean_up; false }
        @glade[UIConsts::MAIN_WINDOW].signal_connect(:show)         { Prefs::instance.load_main(@glade, UIConsts::MAIN_WINDOW) }

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        @glade[UIConsts::MAIN_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE) # It took me ages to research this
        @glade[UIConsts::MAIN_WINDOW].signal_connect("focus_in_event") { |widget, event| @filter_receiver = self; false }

        # Status icon popup menu
        @glade[UIConsts::TTPM_ITEM_PLAY].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_START].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_PAUSE].signal_connect(:activate) { @glade[UIConsts::PLAYER_BTN_START].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_STOP].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_STOP].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_PREV].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_PREV].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_NEXT].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_NEXT].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_QUIT].signal_connect(:activate)  { @glade[UIConsts::MM_FILE_QUIT].send(:activate) }


        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105] ] #, #DragType::URI_LIST],
                      #["image/jpeg", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @ri = @glade[UIConsts::REC_VP_IMAGE]
        Gtk::Drag::dest_set(@ri, Gtk::Drag::DEST_DEFAULT_ALL, dragtable, Gdk::DragContext::ACTION_COPY)
        @ri.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_urls_received(widget, context, x, y, data, info, time) }

        #
        # Generate the submenus for the tags and ratings of the records and tracks popup menus
        # One of worst piece of code ever seen!!!
        #
        #UIConsts::RATINGS.each { |rating| iter = @glade[UIConsts::TRK_CMB_RATING].model.append; iter[0] = rating }

        rating_sm = Gtk::Menu.new
        UIConsts::RATINGS.each { |rating|
            item = Gtk::MenuItem.new(rating, false)
            item.signal_connect(:activate) { |widget| on_set_rating(widget) }
            rating_sm.append(item)
        }
        @glade[UIConsts::REC_POPUP_RATING].submenu = rating_sm
        @glade[UIConsts::TRK_POPUP_RATING].submenu = rating_sm
        rating_sm.show_all

        @tags_handlers = []
        tags_sm = Gtk::Menu.new
        UIConsts::TAGS.each { |tag|
            item = Gtk::CheckMenuItem.new(tag, false)
            @tags_handlers << item.signal_connect(:activate) { |widget| on_set_tags(widget) }
            tags_sm.append(item)
        }
        @glade[UIConsts::REC_POPUP_TAGS].submenu = tags_sm
        @glade[UIConsts::TRK_POPUP_TAGS].submenu = tags_sm
        tags_sm.show_all

        # Disable sensible controls if not in admin mode
        UIConsts::ADMIN_CTRLS.each { |control| @glade[control].sensitive = false } unless Cfg::instance.admin?

        #
        # Setup the treeviews
        #
        @art_browser = ArtistsBrowser.new(self).setup
        @rec_browser = RecordsBrowser.new(self).setup
        @trk_browser = TracksBrowser.new(self).setup

        # Load artists entries
        @art_browser.load_entries

        # At last, we're ready to go!
        @glade[UIConsts::MAIN_WINDOW].icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"audio-cd.png")
        @glade[UIConsts::MAIN_WINDOW].show
    end

    #
    # Save windows positions, windows states and clean up the client music cache
    #
    def clean_up
        @player.stop if @player.playing? || @player.paused?
        Prefs::instance.save_window(@glade[UIConsts::MAIN_WINDOW])
        Prefs::instance.save_menu_state(self, @glade[UIConsts::VIEW_MENU])
        Prefs::instance.save_menu_state(self, @glade[UIConsts::MM_WIN_MENU])
        [@plists, @player, @pqueue, @charts, @filter, @tasks, @memos].each { |tw| tw.hide if tw.window.visible? }
        #system("rm -f ../mfiles/*")
    end

    #
    # Set the check item to false to really close the window
    #
    def notify_closed(window)
        @glade[UIConsts::MM_WIN_PLAYER].active = false if window == @player
        @glade[UIConsts::MM_WIN_PLAYQUEUE].active = false if window == @pqueue
        @glade[UIConsts::MM_WIN_PLAYLISTS].active = false if window == @plists
        @glade[UIConsts::MM_WIN_CHARTS].active = false if window == @charts
        @glade[UIConsts::MM_WIN_FILTER].active = false if window == @filter
        @glade[UIConsts::MM_WIN_TASKS].active = false if window == @tasks
        @glade[UIConsts::MM_WIN_MEMOS].active = false if window == @memos
    end

    def reset_filter_receiver
        @filter_receiver = self # A revoir s'y a une aute fenetre censee recevoir le focus
    end

    def on_urls_received(widget, context, x, y, data, info, time)
        is_ok = false
#         is_ok = Utils::set_cover(data.uris[0], artist.rartist, record.rartist, record.rrecord, track.rtrack) if info == 105
        is_ok = @trk_browser.set_cover(data.uris[0]) if info == 105 #DragType::URI_LIST
        Gtk::Drag.finish(context, is_ok, false, Time.now.to_i)
        return true
    end

    def handle_recent_items(item)
        @recents[item] ? @recents[item].present : @recents[item] = RecentItemsDialog.new(self, item).run
    end

    def recent_items_closed(sender)
#         @recents.each { |dialog| dialog = nil if dialog == sender }
        (RECENT_ADDED..RECENT_PLAYED).each { |i| @recents[i] = nil if @recents[i] == sender }
    end

    #
    # The fucking thing! Don't know how to change the check mark of an item without
    # calling the callback associated!
    #
    def update_tags_menu(pm_owner, menu_item)
        @pm_owner = pm_owner
        tags = track.itags
        i = 1
        c = 0
        menu_item.submenu.each { |child|
            child.signal_handler_block(@tags_handlers[c])
            child.active = tags & i != 0
            child.signal_handler_unblock(@tags_handlers[c])
            i <<= 1
            c += 1
        }
    end

    #
    # Send the value of tags selection to the popup owner so it can do what it wants of it
    #
    def on_set_tags(widget)
        tags = 0
        i = 1
        widget.parent.each { |child| tags |= i if child.active?; i <<= 1 }
        track.itags = tags
        @trk_browser.set_track_field("itags", tags, @pm_owner.instance_of?(RecordsBrowser))
#         @pm_owner.send(:set_tags, tags)
    end

    #
    # Send the value of rating selection to the popup owner so it can do what it wants of it
    #
    def on_set_rating(widget)
        @trk_browser.set_track_field("irating", UIConsts::RATINGS.index(widget.child.label), @pm_owner.instance_of?(RecordsBrowser))
#         @pm_owner.send(:set_rating, UIConsts::RATINGS.index(widget.child.label))
    end


    def toggle_window_visibility(top_window)
        top_window.window.visible? ? top_window.hide : top_window.show
    end


    def show_segment_title?
        return @glade[UIConsts::MM_VIEW_SEGTITLE].active?
    end

    #
    # The following methods allow the browsers to get informations about the current
    # selection of the other browsers and notify the mc when a selection has changed.
    #
    def artist
        return @art_browser.artist.artist
    end

    def record
        return @rec_browser.reclnk.record
    end

    def segment
        return @rec_browser.reclnk.segment
    end

    def is_on_record
        return @rec_browser.is_on_record
    end

    def track
        return @trk_browser.trklnk.track
    end

    def artist_changed
        @rec_browser.load_entries_select_first
    end

    def record_changed
        @trk_browser.load_entries_select_first
    end

    def is_on_never_played?
        return @art_browser.is_on_never_played?
    end

    def is_on_compilations?
        return @art_browser.is_on_compile?
    end

    def invalidate_tabs
        @rec_browser.invalidate
        @trk_browser.invalidate
    end

    def sub_filter
        return @art_browser.sub_filter
    end

    def view_compile?
        return @glade[UIConsts::MM_VIEW_COMPILE].active?
    end

    def change_view_mode
        uilink = @trk_browser.get_current_uilink
        @art_browser.reload
        select_track(uilink) if uilink
    end

    def set_dbrefs_visibility
        [@art_browser, @rec_browser, @trk_browser, @plists].each { |receiver|
            receiver.set_ref_column_visibility(@glade[UIConsts::MM_VIEW_DBREFS].active?)
        }
    end

    # This method is called by the tracks browser when the record is a compile
    # or is segmented in order to keep the artist/segment in sync with the track.
    def change_segment(rsegment)
#         @rec_browser.load_segment(rsegment)
    end

    # Called when browsing compilations to display the current artist infos
    def change_segment_artist(rartist)
        @art_browser.update_segment_artist(rartist)
    end

    def no_selection
        @trk_browser.clear
        @rec_browser.clear
    end

    def update_track_icon(rtrack)
        @trk_browser.update_track_icon(rtrack)
    end

    #
    # Filter management
    #
    def set_filter(where_clause, must_join_logtracks)
        if (where_clause != @main_filter)
            uilink = @trk_browser.get_current_uilink
            @must_join_logtracks = must_join_logtracks
            @main_filter = where_clause
            @art_browser.reload
            select_track(uilink) if uilink
        end
    end

    def reload_plists
        @plists.reload
    end


    def import_sql_file
        batch = ""
        IO.foreach(SQLGenerator::RESULT_SQL_FILE) { |line| batch += line }
        DBUtils::exec_batch(batch, Socket::gethostname)
        @art_browser.reload
        select_record(UILink.new.load_record(record.get_last_id)) # The best guess to find the imported record
    end


    def enqueue_record
        @pqueue.enqueue(@trk_browser.get_tracks_list)
    end

    def download_tracks
        @trk_browser.download_tracks(false)
    end

    def get_tracks_list # Returns all visible tracks
        return @trk_browser.get_tracks_list
    end

    def get_tracks_selection # Returns only selected tracks
        return @trk_browser.get_selection
    end

    def get_plist_selection
        return @plists.get_selection
    end

    def get_pqueue_selection
        return @pqueue.get_selection
    end

    # Only selection message with parameter to know from which recent items we deal with
    def get_recent_selection(param)
        return @recents[param].get_selection
    end

    def get_charts_selection
        return @charts.get_selection
    end

    def get_search_selection
        return @search_dlg.get_selection
    end

    def get_track_uilink(track_index)
        return @trk_browser.get_track_uilink(track_index)
    end


    # Called when typing ctrl+s from the memo window
    def on_save_item
        # If there's no change the db is not updated so we can do it in batch
        # Segment is handled in record class
Trace.log.debug("*** save memos called")
        [@art_browser.artist, @rec_browser.reclnk, @trk_browser.trklnk].each { |dblink| dblink.from_widgets }
    end

    def on_import_audio_file
        file = UIUtils::select_source(Gtk::FileChooser::ACTION_OPEN)
        CDEditorWindow.new.edit_audio_file(file) unless file.empty?
    end

    def on_tag_dir_genre
        value = DBSelectorDialog.new.run(DBIntf::TBL_GENRES)
        unless value == -1
            dir = UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER)
            Utils::tag_full_dir_to_genre(DBUtils::name_from_id(value, DBIntf::TBL_GENRES), dir) unless dir.empty?
        end
    end

    def notify_played(uilink, host = "")
        # If rtrack is -1 the track has been dropped into the pq from the file system
        return if uilink.track.rtrack == -1 || uilink.track.banned?


        # Update local database AND remote database if in client mode
        host = Socket::gethostname if host == ""
        DBUtils::update_track_stats(uilink.track.rtrack, host)

        Thread.new { MusicClient.new.update_stats(uilink.track.rtrack) } if Cfg::instance.remote?

        Thread.new { @charts.live_update(uilink) } if Cfg::instance.live_charts_update? && @charts.window.visible?

        # Update gui if the played track is currently selected. Dangerous if user is modifying the track panel!!!
        @trk_browser.update_infos(uilink.reload_track_cache.track.rtrack)

#         if @glade[UIConsts::MM_VIEW_UPDATENP].active?
#             if @rec_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
#                 @art_browser.update_never_played(ltrack.rrecord, ltrack.rsegment)
#             end
#         end
    end


    def select_artist(rartist, force_reload = false)
        @art_browser.select_artist(rartist) if self.artist.rartist != rartist || force_reload
    end

    def select_record(uilink, force_reload = false)
        select_artist(uilink.record.rartist)
        @rec_browser.select_record(uilink.record.rrecord) if self.record.rrecord != uilink.record.rrecord || force_reload
    end

    def select_segment(uilink, force_reload = false)
        uilink.load_record(uilink.segment.rrecord)
        select_record(uilink)
        @rec_browser.select_segment_from_record_selection(uilink.segment.rsegment) # if self.segment.rsegment != rsegment || force_reload
    end

    def select_track(uilink, force_reload = false)
        rartist = uilink.record.rartist == 0 && !view_compile? ? uilink.segment.rartist : uilink.record.rartist
        select_artist(rartist)
        @rec_browser.select_record(uilink.track.rrecord) if self.record.rrecord != uilink.track.rrecord || force_reload
        @trk_browser.position_to(uilink.track.rtrack) if self.track.rtrack != uilink.track.rtrack || force_reload
    end


    def zoom_rec_image
        cover_name = Utils::get_cover_file_name(record.rrecord, track.rtrack, record.irecsymlink)
        return if cover_name.empty?
        dlg = Gtk::Dialog.new("Cover", nil, Gtk::Dialog::MODAL, [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
        dlg.vbox.add(Gtk::Image.new(cover_name))
        dlg.show_all.run
        dlg.destroy
    end


    #
    # Messages sent by the player to get a track provider
    #
    def get_next_track(is_next)
        meth = is_next ? :get_next_track : :get_prev_track
        return @pqueue.send(meth) if @pqueue.window.visible?
        return @plists.send(meth) if @plists.window.visible?
        return @trk_browser.send(meth)
    end


    #
    # Download database from the server
    #
    #
    def on_update_db
        if Socket::gethostname.match("madD510|192.168.1.14")
            UIUtils::show_message("T'es VRAIMENT TROP CON mon gars!!!", Gtk::MessageDialog::ERROR)
            return
        end
        srv_db_version = MusicClient.new.get_server_db_version
        file = File::basename(DBIntf::build_db_name(srv_db_version)+".dwl")
        @tasks.new_file_download(self, "db"+Cfg::FILE_INFO_SEP+file+Cfg::FILE_INFO_SEP+"0", -1)
    end

    # Still unused but should re-enable all browsers when updating the database.
    def dwl_file_name_notification(user_ref, file_name)
         # Database update: rename the db as db.back and set the downloaded file as the new database.
        if user_ref == -1
            file = DBIntf::build_db_name
            File.unlink(file+".back") if File.exists?(file+".back")
            srv_db_version = MusicClient.new.get_server_db_version
Trace.log.debug("new db version=#{srv_db_version}")
            DBIntf::disconnect
            if srv_db_version == Cfg::instance.db_version
                FileUtils.mv(file, file+".back")
            else
                Prefs::instance.save_db_version(srv_db_version)
            end
            FileUtils.mv(file_name, DBIntf::build_db_name)
            DBCache.instance.clear
        end
    end

    #
    def on_update_resources
        MusicClient.new.synchronize_resources.each { |file| @tasks.new_file_download(self, file, 0) } if Cfg::instance.remote?
    end

    def on_update_sources
        MusicClient.new.synchronize_sources.each { |file| @tasks.new_file_download(self, file, 1) } if Cfg::instance.remote?
    end
end
