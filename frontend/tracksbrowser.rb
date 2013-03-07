

class TracksBrowser < GenericBrowser


    TTV_REF         = 0
    TTV_PIX         = 1
    TTV_ORDER       = 2
    TTV_TITLE       = 3
    TTV_PLAY_TIME   = 4
    TTV_ART_OR_SEG  = 5
    TTV_DATA        = 6

    ROW_REF         = 0
    ROW_ORDER       = 1
    ROW_TITLE       = 2
    ROW_PLAY_TIME   = 3
    ROW_SEG_ORDER   = 4
    ROW_ART_NAME    = 5
    ROW_SEG_REF_ART = 6
    ROW_SEG_TITLE   = 7

    TRK_NOT_FOUND = 0
    TRK_FOUND     = 1
    TRK_MISPLACED = 2
    TRK_ON_SERVER = 3
    TRK_UNKOWN    = 4

    attr_reader :trklnk

    def initialize(mc)
        super(mc, mc.glade[UIConsts::TRACKS_TREEVIEW])
        @trklnk = TrackUI.new # Lost instance but setting to nil is not possible

        @stocks = [Gtk::Stock::NO, Gtk::Stock::YES, Gtk::Stock::DIALOG_WARNING,
                   Gtk::Stock::NETWORK, Gtk::Stock::DIALOG_QUESTION]
    end

    def setup
        renderer = Gtk::CellRendererText.new
        if Cfg::instance.admin?
            renderer.editable = true
            # Reset the text to the true title of the track to remove segment index if any.
            renderer.signal_connect(:editing_started) { |cell, editable, path| editable.text = @trklnk.track.stitle }
            renderer.signal_connect(:edited) { |widget, path, new_text| on_trk_name_edited(widget, path, new_text) }
        end

        pix = Gtk::CellRendererPixbuf.new
        pixcol = Gtk::TreeViewColumn.new("Rip")
        pixcol.pack_start(pix, false)
        pixcol.set_cell_data_func(pix) { |column, cell, model, iter| cell.pixbuf = iter.get_value(TTV_PIX) }

        colNames = ["Ref.", "Track", "Title", "Play time", "Artist"]
        @tv.append_column(Gtk::TreeViewColumn.new(colNames[0], Gtk::CellRendererText.new, :text => TTV_REF))
        @tv.append_column(pixcol)
        @tv.append_column(Gtk::TreeViewColumn.new(colNames[1], Gtk::CellRendererText.new, :text => TTV_ORDER))
        @tv.append_column(Gtk::TreeViewColumn.new(colNames[2], renderer, :text => TTV_TITLE))
        @tv.append_column(Gtk::TreeViewColumn.new(colNames[3], Gtk::CellRendererText.new, :text => TTV_PLAY_TIME))
        @tv.append_column(Gtk::TreeViewColumn.new(colNames[4], Gtk::CellRendererText.new, :text => TTV_ART_OR_SEG))
        (TTV_ORDER..TTV_PLAY_TIME).each { |i| @tv.columns[i].resizable = true }
        @tv.columns[TTV_ART_OR_SEG].visible = false

        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK,
                                     [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]],
                                     Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            tracks = "tracks:message:get_tracks_selection"
#             @tv.selection.selected_each { |model, path, iter| tracks += ":"+iter[0].to_s }
            selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
        }

        @tv.model = Gtk::ListStore.new(Integer, Gdk::Pixbuf, Integer, String, String, String, Class)

        @tv.selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        @tv.selection.mode = Gtk::SELECTION_MULTIPLE
        @tv.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, UIConsts::TRK_POPUP_MENU) }
#         @tv.signal_connect(:start_interactive_search, "mydata") { |tv, data| puts "search started...".green }

        @mc.glade[UIConsts::TRK_POPUP_EDIT].signal_connect(:activate)      { edit_track }
        @mc.glade[UIConsts::TRK_POPUP_ADD].signal_connect(:activate)       { on_trk_add }
        @mc.glade[UIConsts::TRK_POPUP_DEL].signal_connect(:activate)       { on_trk_del }
        @mc.glade[UIConsts::TRK_POPUP_DELFROMFS].signal_connect(:activate) { on_del_from_fs }
#         @mc.glade[UIConsts::TRK_POPUP_DOWNLOAD].signal_connect(:activate)  { on_download_trk }
        @mc.glade[UIConsts::TRK_POPUP_DOWNLOAD].signal_connect(:activate)  { download_tracks(true) }
        @mc.glade[UIConsts::TRK_POPUP_TAGFILE].signal_connect(:activate)   { on_tag_file }
        @mc.glade[UIConsts::TRK_POPUP_UPDPTIME].signal_connect(:activate)  { on_update_playtime }
        @mc.glade[UIConsts::TRK_POPUP_ENQUEUE].signal_connect(:activate)   { on_trk_enqueue(false) }
        @mc.glade[UIConsts::TRK_POPUP_ENQFROM].signal_connect(:activate)   { on_trk_enqueue(true) }

        @mc.glade[UIConsts::TRK_POPUP_AUDIOINFO].signal_connect(:activate) {
            if @trklnk.track.valid? && @trklnk.playable?
                AudioDialog.new.show(@trklnk.audio_file)
            else
                UIUtils::show_message("File not found!", Gtk::MessageDialog::ERROR)
            end
        }
        @mc.glade[UIConsts::TRK_POPUP_PLAYHIST].signal_connect(:activate) {
            PlayHistoryDialog.new.show_track(@trklnk.track.rtrack)
        }
        @mc.glade[UIConsts::TRK_POPUP_CONTPL].signal_connect(:activate) {
            TrkPListsDialog.new(@mc, @trklnk.track.rtrack).run
        }

        # Current track index in browser when it's the player provider
        @curr_track = -1

        return super
    end

    def show_popup(widget, event, menu_name)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            # No popup if no selection in the track tree view except in admin mode (to add track)
            return if @tv.selection.count_selected_rows < 1 && !Cfg::instance.admin?
            # Add segments of the current record to the segment association submenu
            sub_menu = @mc.glade[UIConsts::TRK_POPUP_SEGASS].submenu
            @mc.glade[UIConsts::TRK_POPUP_SEGASS].remove_submenu
            sub_menu.destroy if sub_menu
            if @trklnk.track.rrecord != 0 && @mc.record.valid? #if 0 no tracks in the tree-view
                smtpm = Gtk::Menu.new
                items = []
                if @mc.record.segmented?
                    DBIntf::connection.execute("SELECT stitle FROM segments WHERE rrecord=#{@trklnk.track.rrecord}") { |row|
                        items << Gtk::MenuItem.new(row[0], false)
                        items.last.signal_connect(:activate) { |widget| on_trk_segment_assign(widget) }
                        smtpm.append(items.last)
                    }
                else
                    items << Gtk::MenuItem.new(@mc.record.stitle, false)
                    items.last.signal_connect(:activate) { |widget| on_trk_assign_first_segment(widget) }
                    smtpm.append(items.last)
                end
                @mc.glade[UIConsts::TRK_POPUP_SEGASS].submenu = smtpm
                smtpm.show_all
            end

            # Add play lists to the play lists submenu
            sub_menu = @mc.glade[UIConsts::TRK_POPUP_ADDTOPL].submenu
            @mc.glade[UIConsts::TRK_POPUP_ADDTOPL].remove_submenu
            sub_menu.destroy if sub_menu
            if DBIntf::connection.get_first_value("SELECT COUNT(rplist) FROM plists;").to_i > 0
                pltpm = Gtk::Menu.new
                items = []
                DBIntf::connection.execute("SELECT sname FROM plists ORDER BY sname;") { |row|
                    items << Gtk::MenuItem.new(row[0], false)
                    items.last.signal_connect(:activate) { |widget| on_trk_add_to_pl(widget) }
                    pltpm.append(items.last)
                }
                @mc.glade[UIConsts::TRK_POPUP_ADDTOPL].submenu = pltpm
                pltpm.show_all
            end

            @mc.update_tags_menu(self, @mc.glade[UIConsts::TRK_POPUP_TAGS])

            download_enabled = false
            @tv.selection.selected_each { |model, path, iter|
                if iter[TTV_DATA].audio_status == AudioLink::ON_SERVER
                    download_enabled = true
                    break
                end
            } if @tv.selection
            @mc.glade[UIConsts::TRK_POPUP_DOWNLOAD].sensitive = download_enabled


            @mc.glade[menu_name].popup(nil, nil, event.button, event.time)
        end
    end

    def generate_sql(rtrack = -1)
        sql =  "SELECT tracks.rtrack, tracks.iorder, tracks.stitle, tracks.iplaytime, tracks.isegorder," \
                      "artists.sname, segments.rartist, segments.stitle, tracks.irating, tracks.iplayed FROM tracks " \
                "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                "INNER JOIN artists ON artists.rartist=segments.rartist " \
                "INNER JOIN records ON records.rrecord=tracks.rrecord "
        #sql +=  "INNER JOIN records ON records.rrecord=tracks.rrecord " unless @mc.main_filter.empty?
        if rtrack == -1
            if @mc.artist.rartist == 0 # Artiste compile?
                sql += @mc.is_on_record ? "WHERE tracks.rrecord=#{@mc.record.rrecord}" :
                                          "WHERE tracks.rsegment=#{@mc.segment.rsegment}"
            else
                sql += @mc.is_on_record ? "WHERE tracks.rrecord=#{@mc.record.rrecord} AND segments.rartist=#{@mc.segment.rartist}" :
                                          "WHERE tracks.rsegment=#{@mc.segment.rsegment}"
            end
            sql += @mc.main_filter
            sql += " AND "+@mc.sub_filter unless @mc.sub_filter.empty?
            sql += " ORDER BY "
            sql += "(tracks.irating*1000+tracks.iplayed) DESC, " if @mc.glade[UIConsts::MM_VIEW_BYRATING].active?
            sql += "tracks.iorder;"
        else
            sql += "WHERE rtrack=#{rtrack};"
        end

#p sql
        return sql
    end

    def map_row_to_entry(row, iter)
        iter[TTV_REF]       = row[ROW_REF]
        iter[TTV_ORDER]     = row[ROW_ORDER]
        iter[TTV_TITLE]     = row[ROW_TITLE]
        iter[TTV_TITLE]     = row[ROW_SEG_ORDER].to_s+". "+iter[TTV_TITLE] if row[ROW_SEG_ORDER] != 0 && @mc.glade[UIConsts::MM_VIEW_TRACKINDEX].active?
        iter[TTV_PLAY_TIME] = row[ROW_PLAY_TIME].to_ms_length
        if @tv.columns[TTV_ART_OR_SEG].visible?
            iter[TTV_ART_OR_SEG] = @mc.artist.compile? ? row[ROW_ART_NAME] : row[ROW_SEG_TITLE]
        else
            iter[TTV_ART_OR_SEG] = ""
        end
        iter[TTV_DATA] = TrackUI.new.set_track_ref(iter[TTV_REF])
    end

    def load_entries
        @tv.model.clear

        @tv.columns[TTV_ART_OR_SEG].visible = @mc.artist.compile? ||
                                             (@mc.record.segmented? || !@mc.segment.stitle.empty?) # Show segment name if title not empty
        #@mc.artist.compile? ? @tv.columns[TTV_ART_OR_SEG].title = "Artist" : @tv.columns[TTV_ART_OR_SEG].title = "Segment"
        @tv.columns[TTV_ART_OR_SEG].title = @mc.artist.compile? ? "Artist" : "Segment"

        DBIntf::connection.execute(generate_sql) { |row| map_row_to_entry(row, @tv.model.append) }

        # Sets the icons matching the file status for each entry
        if @mc.glade[UIConsts::MM_VIEW_AUTOCHECK].active?
            check_for_audio_file
        else
            @tv.model.each { |model, path, iter| iter[TTV_PIX] = @tv.render_icon(@stocks[TRK_UNKOWN], Gtk::IconSize::MENU) }
        end
        @tv.columns_autosize

        return self
    end

    def load_entries_select_first
        load_entries
        @tv.set_cursor(@tv.model.iter_first.path, nil, false) if @tv.model.iter_first
        return self
    end

    def update_entry
        map_row_to_entry(DBIntf::connection.get_first_row(generate_sql(@trklnk.track.rtrack)), position_to(@trklnk.track.rtrack))
    end

    def get_selection
        stores = []
        @tv.selection.selected_each { |model, path, iter| stores << iter[TTV_DATA] }
        return stores
    end

    # Returns a list of the the currently visible tracks
    def get_tracks_list
        stores = []
        @tv.model.each { |model, path, iter| stores << iter[TTV_DATA] }
        return stores
    end


    # Set the tags or rating for a selected track(s) or all tracks (when set from records)
    def set_track_field(field, value, to_all)
        meth = to_all ? @tv.model.method(:each) : @tv.selection.method(:selected_each)

        sql = "UPDATE tracks SET #{field}=#{value} WHERE rtrack IN ("
        meth.call { |model, path, iter| sql += iter[TTV_REF].to_s+"," }
        sql[-1] = ")"
p sql
        DBUtils::threaded_client_sql(sql)

        # Refresh the cache
        meth.call { |model, path, iter| iter[TTV_DATA].track.sql_load }

        @trklnk.to_widgets if @trklnk.valid? # @trklnk is invalid if multiple selection was made
    end

    # Returns the uilink for the track at position track_index in the view
    def get_track_uilink(track_index)
        itr = @tv.model.get_iter(track_index.to_s)
        return itr ? itr[TTV_DATA] : nil
    end


    def check_for_audio_file
        # If client mode, it's much too slow to check track by track if it exists on server
        # So check if all tracks exist on disk and if any is not found, ask all tracks state to the server.

        check_on_server = false

        # Get local files first and stores the state of each track
        @tv.model.each { |model, path, iter|
            if iter[TTV_DATA].audio_status.nil? || iter[TTV_DATA].audio_status == AudioLink::UNKNOWN
                check_on_server = true if iter[TTV_DATA].setup_audio_file == AudioLink::NOT_FOUND
            end
        }

        # If client mode and some or all files not found, ask if present on the server
        if Cfg::instance.remote? && check_on_server
            # Save track list to avoid threading problems
            tracks = ""
            @tv.model.each { |mode, path, iter| tracks << iter[TTV_REF].to_s+" " }
            # Replace each file not found state with server state
            MusicClient.new.check_multiple_audio(tracks).each_with_index { |found, i|
                iter = @tv.model.get_iter(i.to_s)
#                 iter[TTV_DATA].audio_status = AudioLink::ON_SERVER if (iter[TTV_DATA].audio_status == AudioLink::NOT_FOUND) && found != '0'
                iter[TTV_DATA].set_audio_status(AudioLink::ON_SERVER) if (iter[TTV_DATA].audio_status == AudioLink::NOT_FOUND) && found != '0'
            }
        end

        # Update tracks icons
        @tv.model.each { |model, path, iter|
            iter[TTV_PIX] = @tv.render_icon(@stocks[iter[TTV_DATA].audio_status], Gtk::IconSize::MENU)
        }
    end

    #
    # Update the track icon when the download is finished
    #
    def update_track_icon(uilink)
        if iter = find_ref(uilink.track.rtrack)
#             iter[TTV_DATA].audio_status = AudioLink::OK
            iter[TTV_PIX] = @tv.render_icon(@stocks[AudioLink::OK], Gtk::IconSize::MENU)
        end
        uilink.set_audio_status(AudioLink::OK)
#         iter[TTV_DATA].audio_status = AudioLink::OK
    end

    # Returns the TrackUI for the currently selected track in the browser.
    # Returns nil if no selection or multi-selection.
    def selected_track
        return @tv.selection.count_selected_rows == 1 ? @tv.model.get_iter(@tv.selection.selected_rows[0])[TTV_DATA] : nil
    end


    # Redraws infos line
    # Emitted by master controller when a track has been played
    def update_infos(rtrack)
        @trklnk.to_widgets if @trklnk.valid? && selected_track == @trklnk
    end

    #
    # Warning about this method: it's called 2 times when browsing:
    #   - first time with count_selected_rows 0
    #   - second time with count_selected_rows 1
    #
    def on_selection_changed(widget)
        return if @tv.selection.count_selected_rows == 0

# Trace.log.debug("track selection changed.".green)
        trackui = selected_track
        if trackui
            # Skip if we're selecting the track that is already selected.
            # Possible when clicking on the selection again and again.
            return if @trklnk.valid? && @trklnk == trackui
# Trace.log.debug("track selection changed.".green)

            @trklnk = trackui
            @trklnk.to_widgets_with_cover

            # Reload artist if artist changed from segment
            @mc.change_segment_artist(@trklnk.segment.rartist) if @trklnk.segment.rartist != @mc.segment.rartist
        else
            # There's nothing to do... may be set artist infos to empty.
# Trace.log.debug("--- multi select ---".magenta)
        end
    end

    def invalidate
        @tv.model.clear
        @mc.glade[UIConsts::REC_IMAGE].pixbuf = ImageCache::instance.default_large_record
        @trklnk.reset.to_widgets if @trklnk.valid?
    end

    def set_cover(url)
        @trklnk.set_cover(url, @mc.artist.compile?).to_widgets_with_cover if @trklnk.track.valid?
#         return if @tv.selection.count_selected_rows == 0
#         iter = @tv.model.get_iter(@tv.selection.selected_rows[0])
#         iter[TTV_DATA].set_cover(url, @mc.artist.compile?)
#         @track.to_widgets_with_cover(iter[TTV_DATA])
    end

    def on_trk_add
        @track.add_new(@mc.record.rrecord, @mc.segment.rsegment)
        rtrack = @track.rtrack # load_entries generates a selection changed event, so rtrack must be saved
        load_entries.position_to(rtrack)
    end

    def on_trk_del
        msg = @tv.selection.count_selected_rows == 1 ? "Sure to delete this track?" : "Sure to delete these tracks?"
        if UIUtils::get_response(msg) == Gtk::Dialog::RESPONSE_OK
            @tv.selection.selected_each { |model, path, iter| UIUtils::delete_track(iter[TTV_REF]); model.remove(iter) }
            load_entries_select_first
        end
    end

    def on_del_from_fs
        msg = @tv.selection.count_selected_rows == 1 ? "Sure to delete this file?" : "Sure to delete these files?"
        if UIUtils::get_response(msg) == Gtk::Dialog::RESPONSE_OK
            @tv.selection.selected_each { |model, path, iter| Utils::remove_file(iter[TTV_REF]) }
            load_entries_select_first
        end
    end

    def on_tag_file
        trackui = selected_track
        return if !trackui || trackui.audio_status == AudioLink::UNKNOWN

        file = UIUtils::select_source(Gtk::FileChooser::ACTION_OPEN, trackui.full_dir)
        trackui.tag_and_move_file(file) unless file.empty?
    end

    def on_update_playtime
        return unless @tv.selection.count_selected_rows == 1
        track_infos = TrackInfos.new.get_track_infos(@track.rtrack)
        fname = Utils::audio_file_exists(track_infos).file_name
        return if fname.empty?
        tags_infos = TrackInfos.new.from_tags(fname)
        @track.iplaytime = tags_infos.track.iplaytime
        @track.sql_update.to_widgets
        DBUtils::update_segment_playtime(@track.rsegment)
        DBUtils::update_record_playtime(@track.rrecord)
        @mc.segment.ref_load(@track.rsegment).to_widgets
        @mc.record.ref_load(@track.rrecord).to_widgets
    end

    def on_trk_name_edited(widget, path, new_text)
        trackui = selected_track
        if trackui.track.stitle != new_text
            file = trackui.audio_file
            # Must rename on server BEFORE the sql update is done!!!
            MusicClient.new.rename_audio(trackui.track.rtrack, new_text) if Cfg::instance.remote?
            trackui.track.stitle = new_text
            trackui.track.sql_update
            trackui.tag_and_move_file(file) unless file.empty? # May be only on server
        end

#         iter = @tv.model.get_iter(@tv.selection.selected_rows[0])
#         if @track.stitle != new_text
#             fname = Utils::audio_file_exists(TrackInfos.new.get_track_infos(iter[TTV_REF])).file_name
#             @track.stitle = iter[TTV_TITLE] = new_text
#             MusicClient.new.rename_audio(iter[TTV_REF], new_text) if Cfg::instance.remote?
#             @track.sql_update.to_widgets
#             Utils::tag_and_move_file(fname, TrackInfos.new.get_track_infos(iter[TTV_REF])) unless fname.empty?
#             update_entry
#         end
    end

    def on_trk_segment_assign(widget)
        @tv.selection.selected_each { |model, path, iter|
            rsegment = DBIntf::connection.get_first_value(
                               "SELECT rsegment FROM segments " \
                               "WHERE rrecord=#{@track.rrecord} AND stitle=#{widget.child.label.to_sql}")
            DBUtils::client_sql("UPDATE tracks SET rsegment=#{rsegment} WHERE rtrack=#{iter[TTV_REF]}")
        }
    end

    def on_trk_assign_first_segment(widget)
        @tv.selection.selected_each { |model, path, iter|
            DBUtils::client_sql("UPDATE tracks SET rsegment=#{@mc.segment.rsegment} WHERE rtrack=#{iter[TTV_REF]}")
        }
    end

    def on_trk_add_to_pl(widget)
        rplist = DBIntf::connection.get_first_value("SELECT rplist FROM plists WHERE sname=#{widget.child.label.to_sql}")
        @tv.selection.selected_each { |model, path, iter| @mc.plists.add_to_plist(rplist, iter[TTV_REF]) }
    end

    def on_trk_enqueue(is_from)
        # Make it thread safe: if in client mode, stores what may change if user changes selection
        # before all requests are made to the server.
        # Juste supposin'... that the loop will finish before any user interaction...
        stores = []
        if is_from
            iter = @tv.model.get_iter(@tv.selection.selected_rows[0])
            begin stores << iter[TTV_DATA] end while iter.next!
        else
            @tv.selection.selected_each { |model, path, iter| stores << iter[TTV_DATA] }
        end
        @mc.pqueue.enqueue(stores)
    end


    def edit_track
        # Voire si c'est vraiment utile de traiter des cas plus qu'exceptionnels...:
        # s'en fout si on a change qqch dans les db refs et qu'on se repositionne pas automatiquement
        # TODO: faire le rename/retag local/remote si le titre/genre a change
        if DBEditor.new(@mc, @trklnk.track).run == Gtk::Dialog::RESPONSE_OK
            # TODO: review this code. It's useless or poorly coded
            load_entries
            @trklnk.track.sql_load
            # TODO: a revoir urgement!
            @mc.select_track(@trklnk)
        end
    end


    def dwl_file_name_notification(uilink, file_name)
        update_track_icon(uilink)
    end

    def on_download_trk
        @tv.selection.selected_each { |model, path, iter|
            if iter[TTV_DATA].audio_status == AudioLink::ON_SERVER
                iter[TTV_DATA].get_remote_audio_file(self, @mc.tasks)
            end
        }
    end

    def download_tracks(use_selection)
        meth = use_selection ? @tv.selection.method(:selected_each) : @tv.model.method(:each)
        meth.call { |model, path, iter|
            if iter[TTV_DATA].audio_status == AudioLink::ON_SERVER
                iter[TTV_DATA].get_remote_audio_file(self, @mc.tasks)
            end
        }
    end

    #
    # Messages sent by the player when track treeview is the track provider
    #
    def get_audio_file
        iter = @tv.model.get_iter(@curr_track.to_s)
        if iter.nil?
            @curr_track = -1
            return nil
        end

        # Faudrait peut-etre boucler pour trouver une track...
        return nil if iter[TTV_DATA].get_audio_file(self, @mc.tasks) == AudioLink::NOT_FOUND

        while iter[TTV_DATA].audio_status == AudioLink::ON_SERVER
            Gtk.main_iteration while Gtk.events_pending?
            sleep(0.1)
        end

        return PlayerData.new(self, @curr_track, iter[TTV_DATA])
    end

    def notify_played(player_data)
        # Nothing to do...
    end

    def reset_player_track
        @curr_track = -1
    end

    def get_next_track
        if @curr_track == -1
            @curr_track = @tv.selection.count_selected_rows == 0 ? 0 : @tv.selection.selected_rows[0].to_s.to_i
        else
            @curr_track += 1
        end
        return get_audio_file
    end

    def get_prev_track
        return nil if @curr_track == 0
        @curr_track -= 1
        return get_audio_file
    end

    def has_more_tracks(is_next)
        if is_next
            return !@tv.model.get_iter((@curr_track+1).to_s).nil?
        else
            return @curr_track-1 >= 0
        end
    end

end
