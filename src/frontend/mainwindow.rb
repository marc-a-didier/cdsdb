
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

    include GtkIDs

    attr_reader :art_browser, :rec_browser, :trk_browser
    attr_reader :history, :search_dlg


    RECENT_ADDED  = 0
    RECENT_RIPPED = 1
    RECENT_PLAYED = 2
    VIEW_BY_DATES = 3

    def initialize(mc)
        super(mc, MAIN_WINDOW)

        @st_icon = Gtk::StatusIcon.new
        @st_icon.stock = Gtk::Stock::CDROM
        if @st_icon.respond_to?(:has_tooltip=) # To keep compat with gtk2 < 2.16
            @st_icon.has_tooltip = true
            @st_icon.signal_connect(:query_tooltip) { |si, x, y, is_kbd, tool_tip|
                @mc.player.show_tooltip(si, tool_tip)
                true
            }
        end
        @st_icon.signal_connect(:popup_menu) { |tray, button, time|
            GtkUI[TTPM_MENU].popup(nil, nil, button, time) { |menu, x, y, push_in|
                @st_icon.position_menu(menu)
            }
        }

        # Var de merde pour savoir d'ou on a clique pour avoir le popup contenant tags ou rating
        # L'owner est donc forcement le treeview des records ou celui des tracks
        # ... En attendant de trouver un truc plus elegant
        @pm_owner = nil


        # Set cd image to default image
        GtkUI[REC_IMAGE].pixbuf = XIntf::Image::Cache.default_large_record

        Gtk::IconTheme.add_builtin_icon("player_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"player.png"))
        Gtk::IconTheme.add_builtin_icon("pqueue_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"pqueue.png"))
        Gtk::IconTheme.add_builtin_icon("plists_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"plists.png"))
        Gtk::IconTheme.add_builtin_icon("charts_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"charts.png"))
        GtkUI[MW_TBBTN_PLAYER].icon_name = "player_icon"
        GtkUI[MW_TBBTN_PQUEUE].icon_name = "pqueue_icon"
        GtkUI[MW_TBBTN_PLISTS].icon_name = "plists_icon"
        GtkUI[MW_TBBTN_CHARTS].icon_name = "charts_icon"

        Gtk::IconTheme.add_builtin_icon("server_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"network-server.png"))
        Gtk::IconTheme.add_builtin_icon("tasks_icon",  22, GtkUtils.get_btn_icon(Cfg.icons_dir+"tasks.png"))
        Gtk::IconTheme.add_builtin_icon("filter_icon", 22, GtkUtils.get_btn_icon(Cfg.icons_dir+"filter.png"))
        Gtk::IconTheme.add_builtin_icon("memos_icon",  22, GtkUtils.get_btn_icon(Cfg.icons_dir+"document-edit.png"))

        GtkUI[MW_TBBTN_SERVER].icon_name = "server_icon"
        GtkUI[MW_TBBTN_TASKS].icon_name  = "tasks_icon"
        GtkUI[MW_TBBTN_FILTER].icon_name = "filter_icon"
        GtkUI[MW_TBBTN_MEMOS].icon_name  = "memos_icon"


        # Connect signals needed to restore windows positions
        GtkUI[MW_PLAYER_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.player)  }
        GtkUI[MW_PQUEUE_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.pqueue)  }
        GtkUI[MW_PLISTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.plists)  }
        GtkUI[MW_CHARTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.charts)  }
        GtkUI[MW_TASKS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@mc.tasks )  }
        GtkUI[MW_FILTER_ACTION].signal_connect(:activate) { toggle_window_visibility(@mc.filters) }
        GtkUI[MW_MEMOS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@mc.memos)   }
        GtkUI[MW_SERVER_ACTION].signal_connect(:activate) {
            Cfg.remote = GtkUI[MW_SERVER_ACTION].active?
            @mc.tasks.check_config
            @trk_browser.check_for_audio_file if @trk_browser
        }

        GtkUI[MM_PLAYER_SRC_AUTO].signal_connect(:activate)    { |widget| @mc.set_player_source(nil) if widget.active?         }
        GtkUI[MM_PLAYER_SRC_PQ].signal_connect(:activate)      { |widget| @mc.set_player_source(@mc.pqueue) if widget.active?  }
        GtkUI[MM_PLAYER_SRC_PLIST].signal_connect(:activate)   { |widget| @mc.set_player_source(@mc.plists) if widget.active?  }
        GtkUI[MM_PLAYER_SRC_BROWSER].signal_connect(:activate) { |widget| @mc.set_player_source(@trk_browser)if widget.active? }

        # Action called from the memos window, equivalent to File/Save of the main window
        GtkUI[MW_MEMO_SAVE_ACTION].signal_connect(:activate) { on_save_item  }

        # Load view menu before instantiating windows (plists case)
        Prefs.load_menu_state(GtkUI[VIEW_MENU])

        # Set windows icons
        @mc.pqueue.window.icon  = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"pqueue.png")
        @mc.player.window.icon  = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"player.png")
        @mc.plists.window.icon  = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"plists.png")
        @mc.charts.window.icon  = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"charts.png")
        @mc.tasks.window.icon   = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"tasks.png")
        @mc.filters.window.icon = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"filter.png")
        @mc.memos.window.icon   = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"document-edit.png")

        # Stores the history window object
        @history = [nil, nil, nil, nil] # Pointer to recent added/ripped/played
        @search_dlg   = nil

        # Reload windows state from the last session BEFORE connecting signals
        [MM_WIN_MENU, MM_EDIT_MENU, MM_PLAYER_MENU,
         MM_VIEW_ST, MM_PLAYER_SRC].each { |menu| Prefs.load_menu_state(GtkUI[menu]) }


        #
        # Toute la plomberie...
        #
        GtkUI[MM_FILE_CHECKCD].signal_connect(:activate)     { Thread.new { CDEditorWindow.new.edit_record } }
        GtkUI[MM_FILE_IMPORTSQL].signal_connect(:activate)   { import_sql_file }
        GtkUI[MM_FILE_IMPORTAUDIO].signal_connect(:activate) { on_import_audio_file }
        #GtkUI[MM_FILE_SAVE].signal_connect(:activate)        { on_save_item }
        GtkUI[MM_FILE_QUIT].signal_connect(:activate)        { @mc.clean_up; Gtk.main_quit }

        GtkUI[MM_EDIT_SEARCH].signal_connect(:activate)      { @search_dlg = Dialogs::Search.new(@mc).run }
        GtkUI[MM_EDIT_PREFS].signal_connect(:activate)       { Dialogs::Preferences.run; @mc.tasks.check_config }


        [MM_VIEW_BYNUMBER, MM_VIEW_BYRATING, MM_VIEW_BYPLAYCOUNT, MM_VIEW_BYDATE, MM_VIEW_BYLENGTH].each { |item|
            GtkUI[item].signal_connect(:activate) { @mc.record_changed   }
        }
        GtkUI[MM_VIEW_COMPILE].signal_connect(:activate)  { change_view_mode }
        GtkUI[MM_VIEW_DBREFS].signal_connect(:activate)   { set_dbrefs_visibility }

        # Faudra revoir, on peut ouvrir plusieurs fenetre des recent items en meme temps...
        GtkUI[MM_WIN_RECENT].signal_connect(:activate) { handle_history(RECENT_ADDED)  }
        GtkUI[MM_WIN_RIPPED].signal_connect(:activate) { handle_history(RECENT_RIPPED) }
        GtkUI[MM_WIN_PLAYED].signal_connect(:activate) { handle_history(RECENT_PLAYED) }
        GtkUI[MM_WIN_DATES].signal_connect(:activate)  { handle_history(VIEW_BY_DATES) }

        GtkUI[MM_TOOLS_BATCHRG].signal_connect(:activate) { Utils.replay_gain_for_genre }
#             Utils::search_for_orphans(GtkUtils.select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER) {
#                 Gtk.main_iteration while Gtk.events_pending?
#             } )
#         }
        GtkUI[MM_TOOLS_TAG_GENRE].signal_connect(:activate)   { on_tag_dir_genre }
        GtkUI[MM_TOOLS_SYNCSRC].signal_connect(:activate)     { on_update_sources }
        GtkUI[MM_TOOLS_SYNCDB].signal_connect(:activate)      { on_update_db }
        GtkUI[MM_TOOLS_SYNCRES].signal_connect(:activate)     { on_update_resources }
        GtkUI[MM_TOOLS_EXPORTDB].signal_connect(:activate)    { Utils.export_to_xml }
        GtkUI[MM_TOOLS_GENREORDER].signal_connect(:activate)  { DBReorderer.new.run }
        GtkUI[MM_TOOLS_CACHEINFO].signal_connect(:activate)   { dump_cacheinfo }
        GtkUI[MM_TOOLS_STATS].signal_connect(:activate)       { Stats.new(@mc).db_stats }
        GtkUI[MM_TOOLS_GRAPH].signal_connect(:activate)       { GraphStats.graph_period }

        GtkUI[MM_DBTOOLS_FULLCHECKLOG].signal_connect(:activate) { DBUtils.check_log_vs_played(true) } # update_log_time
        GtkUI[MM_DBTOOLS_CHECKLOG].signal_connect(:activate)     { DBUtils.check_log_vs_played(false) } # update_log_time
        GtkUI[MM_DBTOOLS_ORPHART].signal_connect(:activate)      { DBUtils.scan_for_orphan_artists }
        GtkUI[MM_DBTOOLS_ORPHREC].signal_connect(:activate)      { DBUtils.scan_for_orphan_records }
        GtkUI[MM_DBTOOLS_ORPHSEG].signal_connect(:activate)      { DBUtils.scan_for_orphan_segments }
        GtkUI[MM_DBTOOLS_ORPHTRK].signal_connect(:activate)      { DBUtils.scan_for_orphan_tracks }

#         GtkUI[MM_ABOUT].signal_connect(:activate) { Credits::show_credits }

        GtkUI[MAIN_WINDOW].signal_connect(:destroy)      { Gtk.main_quit }
        GtkUI[MAIN_WINDOW].signal_connect(:delete_event) { @mc.clean_up; false }

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        GtkUI[MAIN_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE) # It took me ages to research this
        GtkUI[MAIN_WINDOW].signal_connect("focus_in_event") { |widget, event| @mc.filter_receiver = self; false }

        # Status icon popup menu
        GtkUI[TTPM_ITEM_PLAY].signal_connect(:activate)  { GtkUI[PLAYER_BTN_START].send(:clicked) }
        GtkUI[TTPM_ITEM_PAUSE].signal_connect(:activate) { GtkUI[PLAYER_BTN_START].send(:clicked) }
        GtkUI[TTPM_ITEM_STOP].signal_connect(:activate)  { GtkUI[PLAYER_BTN_STOP].send(:clicked) }
        GtkUI[TTPM_ITEM_PREV].signal_connect(:activate)  { GtkUI[PLAYER_BTN_PREV].send(:clicked) }
        GtkUI[TTPM_ITEM_NEXT].signal_connect(:activate)  { GtkUI[PLAYER_BTN_NEXT].send(:clicked) }
        GtkUI[TTPM_ITEM_QUIT].signal_connect(:activate)  { GtkUI[MM_FILE_QUIT].send(:activate) }


        GtkUI[REC_VP_IMAGE].signal_connect("button_press_event") { |widget, event| handle_img_click(widget, event) }

        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105] ]
        Gtk::Drag::dest_set(GtkUI[REC_VP_IMAGE],
                            Gtk::Drag::DEST_DEFAULT_ALL, dragtable,
                            Gdk::DragContext::ACTION_COPY)
        GtkUI[REC_VP_IMAGE].signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time|
            on_urls_received(widget, context, x, y, data, info, time)
        }

        @img_popup = Gtk::Menu.new
        item = Gtk::MenuItem.new('Upload to server', false)
        item.signal_connect(:activate) { |widget|
            @mc.tasks.new_task(TasksWindow::NetworkTask.new(:upload, :covers, @mc.track_xlink.cover_file_name, nil))
        }
        @img_popup.append(item)
        @img_popup.show_all

        #
        # Generate the submenus for the tags and ratings of the records and tracks popup menus
        # One of worst piece of code ever seen!!!
        #
        #RATINGS.each { |rating| iter = GtkUI[TRK_CMB_RATING].model.append; iter[0] = rating }

        rating_sm = Gtk::Menu.new
        Qualifiers::RATINGS.each { |rating|
            item = Gtk::MenuItem.new(rating, false)
            item.signal_connect(:activate) { |widget| on_set_rating(widget) }
            rating_sm.append(item)
        }
        GtkUI[REC_POPUP_RATING].submenu = rating_sm
        GtkUI[TRK_POPUP_RATING].submenu = rating_sm
        rating_sm.show_all

        @tags_handlers = []
        tags_sm = Gtk::Menu.new
        Qualifiers::TAGS.each { |tag|
            item = Gtk::CheckMenuItem.new(tag, false)
            @tags_handlers << item.signal_connect(:activate) { |widget| on_set_tags(widget) }
            tags_sm.append(item)
        }
        GtkUI[REC_POPUP_TAGS].submenu = tags_sm
        GtkUI[TRK_POPUP_TAGS].submenu = tags_sm
        tags_sm.show_all

        # Disable sensible controls if not in admin mode
        ADMIN_CTRLS.each { |control| GtkUI[control].sensitive = false } unless Cfg.admin

        GtkUI[MAIN_WINDOW].icon = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"audio-cd.png")
        GtkUI[MAIN_WINDOW].show

        #
        # Setup the treeviews
        #
        @art_browser = ArtistsBrowser.new.setup(@mc)
        @rec_browser = RecordsBrowser.new.setup(@mc)
        @trk_browser = TracksBrowser.new.setup(@mc)

        # Load artists entries
        @art_browser.load_entries

        set_window_title

        set_dbrefs_visibility
    end

    def set_window_title
        GtkUI[MAIN_WINDOW].title = Cfg.show_count ? "CDsDB #{Cdsdb::VERSION} -- [#{DBUtils.get_total_played}]" : "CDsDB #{Cdsdb::VERSION}"
    end

    def on_urls_received(widget, context, x, y, data, info, time)
        is_ok = false
        is_ok = @trk_browser.set_cover(data.uris[0]) if info == 105 #DragType::URI_LIST
        Gtk::Drag.finish(context, is_ok, false, Time.now.to_i)
        return true
    end

    def handle_history(item)
        if @history[item]
            @history[item].present
        else
            if item == VIEW_BY_DATES
                dates = Dialogs::DateChooser.run
                @history[item] = Dialogs::History.new(@mc, item, dates).run if dates
            else
                @history[item] = Dialogs::History.new(@mc, item, nil).run
            end
        end
    end

    def history_closed(sender)
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
        menu_item.submenu.each do |child|
            child.signal_handler_block(@tags_handlers[c])
            child.active = tags & i != 0
            child.signal_handler_unblock(@tags_handlers[c])
            i <<= 1
            c += 1
        end
    end

    #
    # Send the value of tags selection to the popup owner so it can do what it wants of it
    #
    def on_set_tags(widget)
        bit = 1 << Qualifiers::TAGS.index(widget.child.label)
        bit = -bit unless widget.active? # Send negative value to tell it must be unset
        @trk_browser.set_track_field("itags", bit, @pm_owner.instance_of?(RecordsBrowser))
    end

    #
    # Send the value of rating selection to the popup owner so it can do what it wants of it
    #
    def on_set_rating(widget)
        @trk_browser.set_track_field("irating", Qualifiers::RATINGS.index(widget.child.label), @pm_owner.instance_of?(RecordsBrowser))
    end


    def toggle_window_visibility(top_window)
        top_window.window.visible? ? top_window.hide : top_window.show
    end

    def change_view_mode
        xlink = @trk_browser.trklnk
        @art_browser.reload
        @mc.select_track(xlink) if xlink && xlink.valid_track_ref?
    end

    def set_dbrefs_visibility
        [@art_browser, @rec_browser, @trk_browser, @mc.plists, @mc.filters].each { |receiver|
            receiver.set_ref_column_visibility(GtkUI[MM_VIEW_DBREFS].active?)
        }
    end

    #
    # Filter management: called by filter window (via mc) when a filter is applied
    #
    def set_filter(where_clause, must_join_logtracks)
        if (where_clause != @mc.main_filter)
            xlink = @trk_browser.trklnk
            @mc.main_filter = where_clause
            art_browser.reload
            @mc.select_track(xlink) if xlink && xlink.valid_track_ref?
        end
    end

    def import_sql_file
        DBUtils.exec_batch(IO.binread(DiscAnalyzer::RESULT_SQL_FILE), Cfg.hostname)

        @art_browser.reload
         # The best guess to find the newly imported record
        @mc.select_record(DBCache::Link.new.set_record_ref(DBClasses::Record.new.get_last_id))
    end


    # Called when typing ctrl+s from the memo window
    def on_save_item
        # If there's no change the db is not updated so we can do it in batch
        # Segment is handled in record class
        Trace.debug("*** save memos called")
        [@art_browser.artlnk, @rec_browser.reclnk, @trk_browser.trklnk].each { |dblink| dblink.from_widgets }
    end

    def on_import_audio_file
        file = GtkUtils.select_source(Gtk::FileChooser::ACTION_OPEN)
        CDEditorWindow.new.edit_audio_file(file) unless file.empty?
    end

    def on_tag_dir_genre
        value = Dialogs::DBSelector.new(:rgenre).run
        if value
            dir = GtkUtils.select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER)
            Utils.tag_full_dir_to_genre(DBUtils.name_from_id(value, 'genre'), dir) unless dir.empty?
        end
    end


    def handle_img_click(widget, event)
        # Check if there's a cover other than the default one
        cover_name = @mc.track ? @mc.track_xlink.cover_file_name : nil
        return true unless cover_name

        if event.button == 3 # right mouse button
            @img_popup.popup(nil, nil, event.button, event.time) if Cfg.admin
        else
            dlg = Gtk::Dialog.new("Cover", nil, Gtk::Dialog::MODAL, [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
            dlg.vbox.add(Gtk::Image.new(cover_name))
            dlg.show_all
            dlg.run
            dlg.destroy
        end
        return true
    end

    def dump_cacheinfo
        DBCache::Cache.dump_infos
        XIntf::Image::Cache.dump_infos
    end

    #
    # Download database from the server
    #
    #
    def on_update_db
        unless Cfg.remote?
            GtkUtils.show_message("T'es VRAIMENT TROP CON mon gars!!!", Gtk::MessageDialog::ERROR)
            return
        end
        file = File.basename(DBIntf.build_db_name(MusicClient.get_server_db_version))
        @mc.tasks.new_task(TasksWindow::NetworkTask.new(:download, :db, file, self))
    end

    def task_completed(network_task)
        if network_task.resource_type == :db
            file = DBIntf.build_db_name
            File.unlink(file+'.back') if File.exists?(file+'.back')
            srv_db_version = MusicClient.get_server_db_version
            Trace.debug("server db version=#{srv_db_version}")
            DBIntf.disconnect
            if srv_db_version == DBIntf.db_version
                FileUtils.mv(file, file+'.back')
            else
                # Cfg.set_db_version(srv_db_version)
                # Should warn or exit
                raise 'DB version mismatch'
            end
            FileUtils.mv(Cfg.dir(:db)+network_task.resource_data, DBIntf.build_db_name)
            DBCache::Cache.clear
            @mc.reload_plists.reload_filters
            set_window_title
        end
    end

    def on_update_resources
        [:covers, :flags, :icons].each do |resource_type|
            MusicClient.resources_to_update(resource_type).each do |resource|
                @mc.tasks.new_task(TasksWindow::NetworkTask.new(:download, resource_type, resource, self))
            end
        end if Cfg.remote?
    end

    def on_update_sources
        # MusicClient.synchronize_sources.each { |file| @mc.tasks.new_file_download(self, file, 1) } if Cfg.remote?
    end
end
