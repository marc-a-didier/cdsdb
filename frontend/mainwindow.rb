
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

class MainWindow < TopWindow

    include UIConsts

#     attr_reader   :glade, :plists, :pqueue, :tasks, :filter, :main_filter
#     attr_accessor :filter_receiver

    attr_reader :art_browser, :rec_browser, :trk_browser
    attr_reader :history, :search_dlg


    RECENT_ADDED  = 0
    RECENT_RIPPED = 1
    RECENT_PLAYED = 2
    VIEW_BY_DATES = 3

    def initialize(mc)
        super(mc, MAIN_WINDOW)

#         @glade = GTBld.main
        @mc = mc
        @glade = mc.glade


        @st_icon = Gtk::StatusIcon.new
        @st_icon.stock = Gtk::Stock::CDROM
        if @st_icon.respond_to?(:has_tooltip=) # To keep compat with gtk2 < 2.16
            @st_icon.has_tooltip = true
            @st_icon.signal_connect(:query_tooltip) { |si, x, y, is_kbd, tool_tip|
                @mc.player.playing? ? @mc.player.show_tooltip(si, tool_tip) :
                                     tool_tip.set_markup("\n<b>CDs DB: waiting for tracks to play...</b>\n")
                true
            }
        end
        @st_icon.signal_connect(:popup_menu) { |tray, button, time|
            @glade[TTPM_MENU].popup(nil, nil, button, time) { |menu, x, y, push_in|
                @st_icon.position_menu(menu)
            }
        }

        # Var de merde pour savoir d'ou on a clique pour avoir le popup contenant tags ou rating
        # L'owner est donc forcement le treeview des records ou celui des tracks
        # ... En attendant de trouver un truc plus elegant
        @pm_owner = nil


        # Set cd image to default image
        @glade[REC_IMAGE].pixbuf = IMG_CACHE.default_large_record
        IMG_CACHE.preload_tracks_cover

        Gtk::IconTheme.add_builtin_icon("player_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"player.png"))
        Gtk::IconTheme.add_builtin_icon("pqueue_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"pqueue.png"))
        Gtk::IconTheme.add_builtin_icon("plists_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"plists.png"))
        Gtk::IconTheme.add_builtin_icon("charts_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"charts.png"))
        @glade[MW_TBBTN_PLAYER].icon_name = "player_icon"
        @glade[MW_TBBTN_PQUEUE].icon_name = "pqueue_icon"
        @glade[MW_TBBTN_PLISTS].icon_name = "plists_icon"
        @glade[MW_TBBTN_CHARTS].icon_name = "charts_icon"

        Gtk::IconTheme.add_builtin_icon("information_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"information.png"))
        Gtk::IconTheme.add_builtin_icon("tasks_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"tasks.png"))
        Gtk::IconTheme.add_builtin_icon("filter_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"filter.png"))
        Gtk::IconTheme.add_builtin_icon("memos_icon", 22, UIUtils::get_btn_icon(CFG.icons_dir+"document-edit.png"))

        @glade[MW_TBBTN_APPFILTER].icon_name  = "information_icon"
        @glade[MW_TBBTN_TASKS].icon_name  = "tasks_icon"
        @glade[MW_TBBTN_FILTER].icon_name = "filter_icon"
        @glade[MW_TBBTN_MEMOS].icon_name  = "memos_icon"


        # Connect signals needed to restore windows positions
        @glade[MW_PLAYER_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.player)  }
        @glade[MW_PQUEUE_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.pqueue)  }
        @glade[MW_PLISTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.plists)  }
        @glade[MW_CHARTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.charts)  }
        @glade[MW_TASKS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@mc.tasks )  }
        @glade[MW_FILTER_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.filters) }
        @glade[MW_MEMOS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@mc.memos)   }
        @glade[MW_TBBTN_APPFILTER].signal_connect(:clicked){
            DBCACHE.dump_infos
            IMG_CACHE.dump_infos
        }

        # Action called from the memos window, equivalent to File/Save of the main window
        @glade[MW_MEMO_SAVE_ACTION].signal_connect(:activate) { on_save_item  }

        # Load view menu before instantiating windows (plists case)
        PREFS.load_menu_state(@mc, @glade[VIEW_MENU])

        # Set windows icons
        @mc.pqueue.window.icon  = Gdk::Pixbuf.new(CFG.icons_dir+"pqueue.png")
        @mc.player.window.icon  = Gdk::Pixbuf.new(CFG.icons_dir+"player.png")
        @mc.plists.window.icon  = Gdk::Pixbuf.new(CFG.icons_dir+"plists.png")
        @mc.charts.window.icon  = Gdk::Pixbuf.new(CFG.icons_dir+"charts.png")
        @mc.tasks.window.icon   = Gdk::Pixbuf.new(CFG.icons_dir+"tasks.png")
        @mc.filters.window.icon = Gdk::Pixbuf.new(CFG.icons_dir+"filter.png")
        @mc.memos.window.icon   = Gdk::Pixbuf.new(CFG.icons_dir+"document-edit.png")

        # Stores the history window object
        @history = [nil, nil, nil, nil] # Pointer to recent added/ripped/played
        @search_dlg   = nil

        # Reload windows state from the last session BEFORE connecting signals
        PREFS.load_menu_state(@mc, @glade[MM_WIN_MENU])


        #
        # Toute la plomberie incombant au master controller...
        #
        @glade[MM_FILE_CHECKCD].signal_connect(:activate)     { CDEditorWindow.new.edit_record }
        @glade[MM_FILE_IMPORTSQL].signal_connect(:activate)   { import_sql_file }
        @glade[MM_FILE_IMPORTAUDIO].signal_connect(:activate) { on_import_audio_file }
        #@glade[MM_FILE_SAVE].signal_connect(:activate)        { on_save_item }
        @glade[MM_FILE_QUIT].signal_connect(:activate)        { @mc.clean_up; Gtk.main_quit }

        @glade[MM_EDIT_SEARCH].signal_connect(:activate)      { @search_dlg = SearchDialog.new(@mc).run }
        @glade[MM_EDIT_PREFS].signal_connect(:activate)       { PrefsDialog.new.run; @mc.tasks.check_config }


        @glade[MM_VIEW_BYRATING].signal_connect(:activate) { record_changed   }
        @glade[MM_VIEW_COMPILE].signal_connect(:activate)  { change_view_mode }
        @glade[MM_VIEW_DBREFS].signal_connect(:activate)   { set_dbrefs_visibility }

        # Faudra revoir, on peut ouvrir plusieurs fenetre des recent items en meme temps...
        @glade[MM_WIN_RECENT].signal_connect(:activate) { handle_history(RECENT_ADDED)  }
        @glade[MM_WIN_RIPPED].signal_connect(:activate) { handle_history(RECENT_RIPPED) }
        @glade[MM_WIN_PLAYED].signal_connect(:activate) { handle_history(RECENT_PLAYED) }
        @glade[MM_WIN_DATES].signal_connect(:activate)  { handle_history(VIEW_BY_DATES) }

        @glade[MM_TOOLS_SEARCH_ORPHANS].signal_connect(:activate)     {
            Utils::search_for_orphans(UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER) {
                Gtk.main_iteration while Gtk.events_pending?
            } )
        }
        @glade[MM_TOOLS_TAG_GENRE].signal_connect(:activate)   { on_tag_dir_genre }
        @glade[MM_TOOLS_SCANAUDIO].signal_connect(:activate)   { Utils.scan_for_audio_files(@glade["main_window"]) }
        @glade[MM_TOOLS_CHECKLOG].signal_connect(:activate)    { DBUtils.check_log_vs_played } # update_log_time
        @glade[MM_TOOLS_SYNCSRC].signal_connect(:activate)     { on_update_sources }
        @glade[MM_TOOLS_SYNCDB].signal_connect(:activate)      { on_update_db }
        @glade[MM_TOOLS_SYNCRES].signal_connect(:activate)     { on_update_resources }
        @glade[MM_TOOLS_EXPORTDB].signal_connect(:activate)    { Utils.export_to_xml }
        @glade[MM_TOOLS_GENREORDER].signal_connect(:activate)  { DBReorderer.new.run }
        @glade[MM_TOOLS_RATINGSTEST].signal_connect(:activate) { Utils.test_ratings }
        @glade[MM_TOOLS_STATS].signal_connect(:activate)       { Stats.new(@mc).db_stats }

        @glade[MM_ABOUT].signal_connect(:activate) { Credits::show_credits }

        @glade[REC_VP_IMAGE].signal_connect("button_press_event") { zoom_rec_image }

        @glade[MAIN_WINDOW].signal_connect(:destroy)      { Gtk.main_quit }
        @glade[MAIN_WINDOW].signal_connect(:delete_event) { @mc.clean_up; false }
#         @glade[MAIN_WINDOW].signal_connect(:show)         { PREFS.load_main(@glade, MAIN_WINDOW) }

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        @glade[MAIN_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE) # It took me ages to research this
        @glade[MAIN_WINDOW].signal_connect("focus_in_event") { |widget, event| @mc.filter_receiver = self; false }

        # Status icon popup menu
        @glade[TTPM_ITEM_PLAY].signal_connect(:activate)  { @glade[PLAYER_BTN_START].send(:clicked) }
        @glade[TTPM_ITEM_PAUSE].signal_connect(:activate) { @glade[PLAYER_BTN_START].send(:clicked) }
        @glade[TTPM_ITEM_STOP].signal_connect(:activate)  { @glade[PLAYER_BTN_STOP].send(:clicked) }
        @glade[TTPM_ITEM_PREV].signal_connect(:activate)  { @glade[PLAYER_BTN_PREV].send(:clicked) }
        @glade[TTPM_ITEM_NEXT].signal_connect(:activate)  { @glade[PLAYER_BTN_NEXT].send(:clicked) }
        @glade[TTPM_ITEM_QUIT].signal_connect(:activate)  { @glade[MM_FILE_QUIT].send(:activate) }


        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105] ] #, #DragType::URI_LIST],
                      #["image/jpeg", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @ri = @glade[REC_VP_IMAGE]
        Gtk::Drag::dest_set(@ri, Gtk::Drag::DEST_DEFAULT_ALL, dragtable, Gdk::DragContext::ACTION_COPY)
        @ri.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time|
            on_urls_received(widget, context, x, y, data, info, time)
        }

        #
        # Generate the submenus for the tags and ratings of the records and tracks popup menus
        # One of worst piece of code ever seen!!!
        #
        #RATINGS.each { |rating| iter = @glade[TRK_CMB_RATING].model.append; iter[0] = rating }

        rating_sm = Gtk::Menu.new
        RATINGS.each { |rating|
            item = Gtk::MenuItem.new(rating, false)
            item.signal_connect(:activate) { |widget| on_set_rating(widget) }
            rating_sm.append(item)
        }
        @glade[REC_POPUP_RATING].submenu = rating_sm
        @glade[TRK_POPUP_RATING].submenu = rating_sm
        rating_sm.show_all

        @tags_handlers = []
        tags_sm = Gtk::Menu.new
        TAGS.each { |tag|
            item = Gtk::CheckMenuItem.new(tag, false)
            @tags_handlers << item.signal_connect(:activate) { |widget| on_set_tags(widget) }
            tags_sm.append(item)
        }
        @glade[REC_POPUP_TAGS].submenu = tags_sm
        @glade[TRK_POPUP_TAGS].submenu = tags_sm
        tags_sm.show_all

        # Disable sensible controls if not in admin mode
        ADMIN_CTRLS.each { |control| @glade[control].sensitive = false } unless CFG.admin?

        #
        # Setup the treeviews
        #
        @art_browser = ArtistsBrowser.new(@mc).setup
        @rec_browser = RecordsBrowser.new(@mc).setup
        @trk_browser = TracksBrowser.new(@mc).setup

        # Load artists entries
        @art_browser.load_entries

        # At last, we're ready to go!
        @glade[MAIN_WINDOW].icon = Gdk::Pixbuf.new(CFG.icons_dir+"audio-cd.png")
        @glade[MAIN_WINDOW].show
    end

    def on_urls_received(widget, context, x, y, data, info, time)
        is_ok = false
#         is_ok = Utils::set_cover(data.uris[0], artist.rartist, record.rartist, record.rrecord, track.rtrack) if info == 105
        is_ok = @trk_browser.set_cover(data.uris[0]) if info == 105 #DragType::URI_LIST
        Gtk::Drag.finish(context, is_ok, false, Time.now.to_i)
        return true
    end

    def handle_history(item)
        if @history[item]
            @history[item].present
        else
            if item == VIEW_BY_DATES
                dlg = DateChooser.new.run
                dates = dlg.dates
                dlg.close
                @history[item] = HistoryDialog.new(@mc, item, dates).run if dates
            else
                @history[item] = HistoryDialog.new(@mc, item, nil).run
            end
        end
    end

    def history_closed(sender)
#         @history.each { |dialog| dialog = nil if dialog == sender }
        (RECENT_ADDED..VIEW_BY_DATES).each { |i| @history[i] = nil if @history[i] == sender }
    end

    #
    # The fucking thing! Don't know how to change the check mark of an item without
    # calling the callback associated!
    #
    def update_tags_menu(pm_owner, menu_item)
        @pm_owner = pm_owner
        tags = @mc.track.itags
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
        bit = 1 << TAGS.index(widget.child.label)
        bit = -bit unless widget.active? # Send negative value to tell it must be unset
        @trk_browser.set_track_field("itags", bit, @pm_owner.instance_of?(RecordsBrowser))
    end

    #
    # Send the value of rating selection to the popup owner so it can do what it wants of it
    #
    def on_set_rating(widget)
        @trk_browser.set_track_field("irating", RATINGS.index(widget.child.label), @pm_owner.instance_of?(RecordsBrowser))
    end


    def toggle_window_visibility(top_window)
        top_window.window.visible? ? top_window.hide : top_window.show
    end

    def change_view_mode
        uilink = @trk_browser.trklnk
        @art_browser.reload
        @mc.select_track(uilink) if uilink
    end

    def set_dbrefs_visibility
        [@art_browser, @rec_browser, @trk_browser, @mc.plists, @mc.filters].each { |receiver|
            receiver.set_ref_column_visibility(@glade[MM_VIEW_DBREFS].active?)
        }
    end

    #
    # Filter management: called by filter window (via mc) when a filter is applied
    #
    def set_filter(where_clause, must_join_logtracks)
        if (where_clause != @mc.main_filter)
            uilink = trk_browser.trklnk
            @mc.main_filter = where_clause
            art_browser.reload
            @mc.select_track(uilink) if uilink
        end
    end

    def import_sql_file
        batch = ""
        IO.foreach(SQLGenerator::RESULT_SQL_FILE) { |line| batch += line }
        DBUtils.exec_batch(batch, Socket.gethostname)
        @art_browser.reload
        @mc.select_record(UILink.new.set_record_ref(RecordDBClass.new.get_last_id)) # The best guess to find the imported record
    end


    # Called when typing ctrl+s from the memo window
    def on_save_item
        # If there's no change the db is not updated so we can do it in batch
        # Segment is handled in record class
TRACE.debug("*** save memos called")
        [@art_browser.artlnk, @rec_browser.reclnk, @trk_browser.trklnk].each { |dblink| dblink.from_widgets }
    end

    def on_import_audio_file
        file = UIUtils.select_source(Gtk::FileChooser::ACTION_OPEN)
        CDEditorWindow.new.edit_audio_file(file) unless file.empty?
    end

    def on_tag_dir_genre
        value = DBSelectorDialog.new.run(DBIntf::TBL_GENRES)
        unless value == -1
            dir = UIUtils.select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER)
            Utils.tag_full_dir_to_genre(DBUtils.name_from_id(value, DBIntf::TBL_GENRES), dir) unless dir.empty?
        end
    end


    def zoom_rec_image
        cover_name = Utils.get_cover_file_name(@mc.record.rrecord, @mc.track.rtrack, @mc.record.irecsymlink)
        return if cover_name.empty?
        dlg = Gtk::Dialog.new("Cover", nil, Gtk::Dialog::MODAL, [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
        dlg.vbox.add(Gtk::Image.new(cover_name))
        dlg.show_all.run
        dlg.destroy
    end


    #
    # Download database from the server
    #
    #
    def on_update_db
        if Socket.gethostname.match("madD510|192.168.1.14") || !CFG.remote?
            UIUtils.show_message("T'es VRAIMENT TROP CON mon gars!!!", Gtk::MessageDialog::ERROR)
            return
        end
        srv_db_version = MusicClient.new.get_server_db_version
        file = File.basename(DBIntf.build_db_name(srv_db_version)+".dwl")
        @mc.tasks.new_file_download(self, "db"+Cfg::FILE_INFO_SEP+file+Cfg::FILE_INFO_SEP+"0", -1)
    end

    # Still unused but should re-enable all browsers when updating the database.
    def dwl_file_name_notification(user_ref, file_name)
         # Database update: rename the db as db.back and set the downloaded file as the new database.
        if user_ref == -1
            file = DBIntf.build_db_name
            File.unlink(file+".back") if File.exists?(file+".back")
            srv_db_version = MusicClient.new.get_server_db_version
TRACE.debug("new db version=#{srv_db_version}")
            DBIntf.disconnect
            if srv_db_version == CFG.db_version
                FileUtils.mv(file, file+".back")
            else
                PREFS.save_db_version(srv_db_version)
            end
            FileUtils.mv(file_name, DBIntf::build_db_name)
            DBCACHE.clear
            DBIntf.connect
            @mc.reload_plists.reload_filters
        end
    end

    #
    def on_update_resources
        MusicClient.new.synchronize_resources.each { |file| @mc.tasks.new_file_download(self, file, 0) } if CFG.remote?
    end

    def on_update_sources
        MusicClient.new.synchronize_sources.each { |file| @mc.tasks.new_file_download(self, file, 1) } if CFG.remote?
    end
end
