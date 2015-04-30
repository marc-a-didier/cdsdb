

class TracksBrowser < Gtk::TreeView

    include PlayerIntf
    include PlayerIntf::Browser

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

    def initialize
        super
        @trklnk = XIntf::Track.new # Lost instance but setting to nil is not possible

        @stocks = [Gtk::Stock::NO, Gtk::Stock::YES, Gtk::Stock::DIALOG_WARNING,
                   Gtk::Stock::NETWORK, Gtk::Stock::DIALOG_QUESTION]
    end

    def setup(mc)
        @mc = mc
        GtkUI[GtkIDs::TRACKS_TVC].add(self)
        self.visible = true

        renderer = Gtk::CellRendererText.new
        if Cfg.admin
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
        title_col = Gtk::TreeViewColumn.new(colNames[2], renderer, :text => TTV_TITLE)
        append_column(Gtk::TreeViewColumn.new(colNames[0], Gtk::CellRendererText.new, :text => TTV_REF))
        append_column(pixcol)
        append_column(Gtk::TreeViewColumn.new(colNames[1], Gtk::CellRendererText.new, :text => TTV_ORDER))
        append_column(title_col)
        append_column(Gtk::TreeViewColumn.new(colNames[3], Gtk::CellRendererText.new, :text => TTV_PLAY_TIME))
        append_column(Gtk::TreeViewColumn.new(colNames[4], Gtk::CellRendererText.new, :text => TTV_ART_OR_SEG))
        (TTV_ORDER..TTV_PLAY_TIME).each { |i| columns[i].resizable = true }
        columns[TTV_ART_OR_SEG].visible = false

        title_col.set_cell_data_func(renderer) do |col, renderer, model, iter|
            green = iter[TTV_DATA].track.iplayed
            green = 255 if green > 255
            renderer.set_foreground(sprintf('#00%02x00', green))
#             other = 255-green
#             renderer.set_background(sprintf('#%02x%02x%02x', other, green, other))
        end

        enable_model_drag_source(Gdk::Window::BUTTON1_MASK,
                                 [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]],
                                 Gdk::DragContext::ACTION_COPY)
        signal_connect(:drag_data_get) do |widget, drag_context, selection_data, info, time|
            tracks = "tracks:message:get_tracks_selection"
            selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
        end

        self.model = Gtk::ListStore.new(Integer, Gdk::Pixbuf, Integer, String, String, String, Class)

        selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        selection.mode = Gtk::SELECTION_MULTIPLE
        signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, GtkIDs::TRK_POPUP_MENU) }
#         @tv.signal_connect(:start_interactive_search, "mydata") { |tv, data| puts "search started...".green }

        GtkUI[GtkIDs::TRK_POPUP_EDIT].signal_connect(:activate)      { edit_track }
        GtkUI[GtkIDs::TRK_POPUP_ADD].signal_connect(:activate)       { on_trk_add }
        GtkUI[GtkIDs::TRK_POPUP_DEL].signal_connect(:activate)       { on_trk_del }
        GtkUI[GtkIDs::TRK_POPUP_DELFROMFS].signal_connect(:activate) { on_del_from_fs }
        GtkUI[GtkIDs::TRK_POPUP_DOWNLOAD].signal_connect(:activate)  { download_tracks(true) }
        GtkUI[GtkIDs::TRK_POPUP_TAGFILE].signal_connect(:activate)   { on_tag_file }
        GtkUI[GtkIDs::TRK_POPUP_UPDPTIME].signal_connect(:activate)  { on_update_playtime }
        GtkUI[GtkIDs::TRK_POPUP_ENQUEUE].signal_connect(:activate)   { on_trk_enqueue(false) }
        GtkUI[GtkIDs::TRK_POPUP_ENQFROM].signal_connect(:activate)   { on_trk_enqueue(true) }

        GtkUI[GtkIDs::TRK_POPUP_AUDIOINFO].signal_connect(:activate) do
            if @trklnk.valid_track_ref? && @trklnk.playable?
                Dialogs::Audio.run(@trklnk.audio_file)
            else
                GtkUtils.show_message("File not found!", Gtk::MessageDialog::ERROR)
            end
        end
        GtkUI[GtkIDs::TRK_POPUP_PLAYHIST].signal_connect(:activate) {
            Dialogs::PlayHistory.show_track(@trklnk.track.rtrack)
        }
        GtkUI[GtkIDs::TRK_POPUP_CONTPL].signal_connect(:activate) {
            Dialogs::TrackPLists.run(@mc, @trklnk.track.rtrack)
        }

        # Current track index in browser when it's the player provider
        @track_ref = -1

        return finalize_setup
    end

    def show_popup(widget, event, menu_name)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            # No popup if no selection in the track tree view except in admin mode (to add track)
            return if selection.count_selected_rows < 1 && !Cfg.admin
            # Add segments of the current record to the segment association submenu
            sub_menu = GtkUI[GtkIDs::TRK_POPUP_SEGASS].submenu
            GtkUI[GtkIDs::TRK_POPUP_SEGASS].remove_submenu
            sub_menu.destroy if sub_menu
            if @trklnk.track.rrecord != 0 && @mc.record.valid? #if 0 no tracks in the tree-view
                smtpm = Gtk::Menu.new
                items = []
                if @mc.record.segmented?
                    DBIntf.execute("SELECT stitle FROM segments WHERE rrecord=#{@trklnk.track.rrecord}") do |row|
                        items << Gtk::MenuItem.new(row[0], false)
                        items.last.signal_connect(:activate) { |widget| on_trk_segment_assign(widget) }
                        smtpm.append(items.last)
                    end
                else
                    items << Gtk::MenuItem.new(@mc.record.stitle, false)
                    items.last.signal_connect(:activate) { |widget| on_trk_assign_first_segment(widget) }
                    smtpm.append(items.last)
                end
                GtkUI[GtkIDs::TRK_POPUP_SEGASS].submenu = smtpm
                smtpm.show_all
            end

            # Add play lists to the play lists submenu
            sub_menu = GtkUI[GtkIDs::TRK_POPUP_ADDTOPL].submenu
            GtkUI[GtkIDs::TRK_POPUP_ADDTOPL].remove_submenu
            sub_menu.destroy if sub_menu
            if DBIntf.get_first_value("SELECT COUNT(rplist) FROM plists;").to_i > 0
                pltpm = Gtk::Menu.new
                items = []
                DBIntf.execute("SELECT sname FROM plists ORDER BY sname;") do |row|
                    items << Gtk::MenuItem.new(row[0], false)
                    items.last.signal_connect(:activate) { |widget| on_trk_add_to_pl(widget) }
                    pltpm.append(items.last)
                end
                GtkUI[GtkIDs::TRK_POPUP_ADDTOPL].submenu = pltpm
                pltpm.show_all
            end

            @mc.update_tags_menu(self, GtkUI[GtkIDs::TRK_POPUP_TAGS])

            download_enabled = false
            selection.selected_each do |model, path, iter|
                if iter[TTV_DATA].audio_status == Audio::Status::ON_SERVER
                    download_enabled = true
                    break
                end
            end if self.selection
            GtkUI[GtkIDs::TRK_POPUP_DOWNLOAD].sensitive = download_enabled


            GtkUI[menu_name].popup(nil, nil, event.button, event.time)
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
            sql += "(tracks.irating*1000+tracks.iplayed) DESC, " if GtkUI[GtkIDs::MM_VIEW_BYRATING].active?
            sql += "tracks.iplayed DESC, " if GtkUI[GtkIDs::MM_VIEW_BYPLAYCOUNT].active?
            sql += "tracks.iorder;"
        else
            sql += "WHERE rtrack=#{rtrack};"
        end

        return sql
    end

    def map_row_to_entry(row, iter)
        iter[TTV_REF]       = row[ROW_REF]
        iter[TTV_ORDER]     = row[ROW_ORDER]
        iter[TTV_TITLE]     = row[ROW_TITLE]
        iter[TTV_TITLE]     = row[ROW_SEG_ORDER].to_s+". "+iter[TTV_TITLE] if row[ROW_SEG_ORDER] != 0 && GtkUI[GtkIDs::MM_VIEW_TRACKINDEX].active?
        iter[TTV_PLAY_TIME] = row[ROW_PLAY_TIME].to_ms_length
        if columns[TTV_ART_OR_SEG].visible?
            iter[TTV_ART_OR_SEG] = @mc.artist.compile? ? row[ROW_ART_NAME] : row[ROW_SEG_TITLE]
        else
            iter[TTV_ART_OR_SEG] = ""
        end
        iter[TTV_DATA] = XIntf::Track.new.set_track_ref(iter[TTV_REF])
    end

    def load_entries
        # if no artist, we're probably trying to load but there's no reference.
        # example: change track view mode while no selection has been made in the browser.
        return self unless @mc.artist

        model.clear

        columns[TTV_ART_OR_SEG].visible = @mc.artist.compile? ||
                                         (@mc.record.segmented? || !@mc.segment.stitle.empty?) # Show segment name if title not empty
        #@mc.artist.compile? ? @tv.columns[TTV_ART_OR_SEG].title = "Artist" : @tv.columns[TTV_ART_OR_SEG].title = "Segment"
        columns[TTV_ART_OR_SEG].title = @mc.artist.compile? ? "Artist" : "Segment"

        DBIntf.execute(generate_sql) { |row| map_row_to_entry(row, model.append) }

        # Sets the icons matching the file status for each entry
        if GtkUI[GtkIDs::MM_VIEW_AUTOCHECK].active?
            check_for_audio_file
        else
            model.each { |model, path, iter| iter[TTV_PIX] = render_icon(@stocks[TRK_UNKOWN], Gtk::IconSize::MENU) }
        end
        columns_autosize

        reset_player_data_state

        return self
    end

    def load_entries_select_first
        load_entries
        set_cursor(model.iter_first.path, nil, false) if model.iter_first
        return self
    end

    def update_entry
        map_row_to_entry(DBIntf.get_first_row(generate_sql(@trklnk.track.rtrack)), position_to(@trklnk.track.rtrack))
    end

    def get_selection
        links = []
        selection.selected_each { |model, path, iter| links << iter[TTV_DATA] } #.clone }
        return links
    end

    # Returns a list of the the currently visible tracks
    def get_tracks_list
        links = []
        model.each { |model, path, iter| links << iter[TTV_DATA] } #.clone }
        return links
    end


    # Set the tags or rating for a selected track(s) or all tracks (when set from records)
    def set_track_field(field, value, to_all)
        meth = to_all ? model.method(:each) : selection.method(:selected_each)

        sql = "UPDATE tracks SET #{field}="
        if field == "itags"
            operator = value < 0 ? "& ~" : "|"
            sql += "#{field} #{operator} #{value.abs}"
        else
            sql += value.to_s
        end
        sql += " WHERE rtrack IN ("
        meth.call { |model, path, iter| sql += iter[TTV_REF].to_s+"," }
        sql[-1] = ")"

        DBUtils.threaded_client_sql(sql)

        # Refresh the cache
        meth.call { |model, path, iter| iter[TTV_DATA].track.sql_load }

        @trklnk.to_widgets if @trklnk.valid_track_ref? # @trklnk is invalid if multiple selection was made
    end

    def check_for_audio_file
        # If client mode, it's much too slow to check track by track if it exists on server
        # So check if all tracks exist on disk and if any is not found, ask all tracks state to the server.

        check_on_server = false

        # Get local files first and stores the state of each track
        model.each do |model, path, iter|
            if iter[TTV_DATA].audio_status.nil? || iter[TTV_DATA].audio_status == Audio::Status::UNKNOWN
                check_on_server = true if iter[TTV_DATA].setup_audio_file.status == Audio::Status::NOT_FOUND
            end
        end

        # If client mode and some or all files not found, ask if present on the server
        if Cfg.remote? && check_on_server
            # Save track list to avoid threading problems
            tracks = ""
            model.each { |mode, path, iter| tracks << iter[TTV_REF].to_s+" " }
            # Replace each file not found state with server state
            MusicClient.check_multiple_audio(tracks).each_with_index do |found, i|
                iter = model.get_iter(i.to_s)
                iter[TTV_DATA].set_audio_status(Audio::Status::ON_SERVER) if (iter[TTV_DATA].audio_status == Audio::Status::NOT_FOUND) && found != '0'
            end
        end

        # Update tracks icons
        model.each { |model, path, iter|
            iter[TTV_PIX] = render_icon(@stocks[iter[TTV_DATA].audio_status], Gtk::IconSize::MENU)
        }
    end

    #
    # Set the status of audio link to OK and update the icon if visible
    #
    def audio_link_ok(xlink)
        xlink.set_audio_status(Audio::Status::OK)
        xlink.setup_audio_file
        if iter = find_ref(xlink.track.rtrack)
            iter[TTV_PIX] = render_icon(@stocks[Audio::Status::OK], Gtk::IconSize::MENU)
        end
    end

    # Returns the XIntf::Track for the currently selected track in the browser.
    # Returns nil if no selection or multi-selection.
    def selected_track
        return selection.count_selected_rows == 1 ? model.get_iter(selection.selected_rows[0])[TTV_DATA] : nil
    end


    # Redraws infos line
    # Emitted by master controller when a track has been played
    def update_infos
        @trklnk.to_widgets if @trklnk.valid_track_ref? && selected_track == @trklnk
    end

    #
    # Warning about this method: it's called 2 times when browsing:
    #   - first time with count_selected_rows 0
    #   - second time with count_selected_rows 1
    #
    def on_selection_changed(widget)
        return if selection.count_selected_rows == 0

        # Trace.debug("track selection changed.".green)
        xtrack = selected_track
        if xtrack
            # Skip if we're selecting the track that is already selected.
            # Possible when clicking on the selection again and again.
            return if @trklnk.valid_track_ref? && @trklnk == xtrack
            # Trace.debug("track selection changed.".brown)

            @trklnk = xtrack
            @trklnk.to_widgets_with_cover

            # Reload artist if artist changed from segment
            @mc.set_segment_artist(@trklnk) if @trklnk.segment.rartist != @mc.segment.rartist
        else
            # There's nothing to do... may be set artist infos to empty.
            # Trace.debug("--- multi select ---".magenta)
        end
    end

    def invalidate
        model.clear
        GtkUI[GtkIDs::REC_IMAGE].pixbuf = XIntf::Image::Cache.default_large_record
        @trklnk.reset.to_widgets if @trklnk.valid_track_ref?
    end

    def set_cover(url)
        @trklnk.set_cover(url, @mc.artist.compile?).to_widgets_with_cover if @trklnk.valid_track_ref?
    end

    def on_trk_add
        @track.add_new(@mc.record.rrecord, @mc.segment.rsegment)
        rtrack = @track.rtrack # load_entries generates a selection changed event, so rtrack must be saved
        load_entries.position_to(rtrack)
    end

    def on_trk_del
        msg = selection.count_selected_rows == 1 ? "Sure to delete this track?" : "Sure to delete these tracks?"
        if GtkUtils.get_response(msg) == Gtk::Dialog::RESPONSE_OK
            selection.selected_each { |model, path, iter| GtkUtils.delete_track(iter[TTV_REF]); model.remove(iter) }
            load_entries_select_first
        end
    end

    def on_del_from_fs
        msg = selection.count_selected_rows == 1 ? "Sure to delete this file?" : "Sure to delete these files?"
        if GtkUtils.get_response(msg) == Gtk::Dialog::RESPONSE_OK
            selection.selected_each { |model, path, iter| iter[TTV_DATA].remove_from_fs }
            check_for_audio_file
        end
    end

    def on_tag_file
        xtrack = selected_track
        return if !xtrack || !xtrack.playable?

        file = GtkUtils.select_source(Gtk::FileChooser::ACTION_OPEN, xtrack.full_dir)
        unless file.empty?
            xtrack.set_artist_ref(@mc.segment.rartist)
            xtrack.tag_and_move_file(file)
            audio_link_ok(xtrack)
        end
    end

    def on_update_playtime
        xtrack = selected_track
        return if !xtrack || !xtrack.playable?
#         return unless selection.count_selected_rows == 1
#         track_infos = TrackInfos.new.get_track_infos(@track.rtrack)
#         fname = Utils::audio_file_exists(track_infos).file_name
#         return if fname.empty?
#         tags_infos = TrackInfos.new.from_tags(fname)
#         @track.iplaytime = tags_infos.track.iplaytime
#         @track.iplaytime = file.tags.iplaytime
        @track.iplaytime = Audio::Link.new.load_from_tags(xtrack.audio_file).tags.iplaytime
        @track.sql_update.to_widgets

        DBUtils.update_segment_playtime(@track.rsegment)
        DBUtils.update_record_playtime(@track.rrecord)

        @mc.segment.ref_load(@track.rsegment).to_widgets
        @mc.record.ref_load(@track.rrecord).to_widgets
    end

    def on_trk_name_edited(widget, path, new_text)
        xtrack = selected_track
        if xtrack.track.stitle != new_text
            # WARNING It may happen that the file name has no extension
            #         under exceptional and unclear circumstances

            # Must rename on server BEFORE the sql update is done because it needs the old name to find the track!!
            MusicClient.rename_audio(xtrack.track.rtrack, new_text) if Cfg.remote?

            xtrack.track.stitle = new_text
            xtrack.track.sql_update

            xtrack.tag_and_move_file(xtrack.audio_file) if xtrack.playable?
        end
    end

    def on_trk_segment_assign(widget)
        selection.selected_each do |model, path, iter|
            rsegment = DBIntf.get_first_value(
                               "SELECT rsegment FROM segments " \
                               "WHERE rrecord=#{@track.rrecord} AND stitle=#{widget.child.label.to_sql}")
            DBUtils.client_sql("UPDATE tracks SET rsegment=#{rsegment} WHERE rtrack=#{iter[TTV_REF]}")
        end
    end

    def on_trk_assign_first_segment(widget)
        selection.selected_each { |model, path, iter|
            DBUtils.client_sql("UPDATE tracks SET rsegment=#{@mc.segment.rsegment} WHERE rtrack=#{iter[TTV_REF]}")
        }
    end

    def on_trk_add_to_pl(widget)
        rplist = DBIntf.get_first_value("SELECT rplist FROM plists WHERE sname=#{widget.child.label.to_sql}")
        selection.selected_each { |model, path, iter| @mc.plists.add_to_plist(rplist, iter[TTV_REF]) }
    end

    def on_trk_enqueue(is_from)
        # Sends the current selection of track(s) to the play queue.
        # If is_from is true, sends all tracks starting from the current selection
        links = []
        if is_from
            iter = model.get_iter(selection.selected_rows[0])
            begin links << iter[TTV_DATA] end while iter.next!
        else
            selection.selected_each { |model, path, iter| links << iter[TTV_DATA] }
        end
        @mc.pqueue.enqueue(links)
    end


    def edit_track
        # Voire si c'est vraiment utile de traiter des cas plus qu'exceptionnels...:
        # s'en fout si on a change qqch dans les db refs et qu'on se repositionne pas automatiquement
        # TODO: faire le rename/retag local/remote si le titre/genre a change
        if XIntf::Editors::Main.new(@mc, @trklnk, XIntf::Editors::TRACK_PAGE).run == Gtk::Dialog::RESPONSE_OK
            # TODO: review this code. It's useless or poorly coded
#             load_entries
#             @trklnk.track.sql_load
            # TODO: a revoir urgement!
#             @mc.select_track(@trklnk)
            @trklnk.to_widgets_with_cover
        end
    end

    def task_completed(network_task)
        audio_link_ok(network_task.resource_data)
        @mc.track_list_changed(self)
    end

    def download_tracks(use_selection)
        selection.send(use_selection ? :selected_each : :each) do |model, path, iter|
            if iter[TTV_DATA].audio_status == Audio::Status::ON_SERVER
                iter[TTV_DATA].get_remote_audio_file(TasksWindow::NetworkTask.new(:download, :track, iter[TTV_DATA], self), @mc.tasks)
            end
        end
    end

    def upload_tracks
        tracks = ''
        model.each { |model, path, iter| (tracks << iter[TTV_REF].to_s+' ') if iter[TTV_DATA].audio_status == Audio::Status::OK }
        # Replace each file not found state with server state
        MusicClient.check_multiple_audio(tracks).each_with_index do |found, i|
            if found == '0'
                @mc.tasks.new_task(TasksWindow::NetworkTask.new(:upload, :track, model.get_iter(i.to_s)[TTV_DATA].audio_file, nil))
            end
        end

        Trace.debug("Checking cover file: #{model.get_iter('0')[TTV_DATA].cover_file_name}")
        unless MusicClient.has_resource(:covers, model.get_iter('0')[TTV_DATA].cover_file_name)
            @mc.tasks.new_task(TasksWindow::NetworkTask.new(:upload, :covers, model.get_iter('0')[TTV_DATA].cover_file_name, nil))
        end
    end


    def reset_player_data_state
        @track_ref = -1
        @mc.unfetch_player(self)
    end

    #
    # PlayerIntf & BrowserPlayerIntf implementation
    #

    def started_playing(player_data)
        do_started_playing(self, player_data)
    end

    def prefetch_tracks(queue, max_entries)
        if queue[0] && queue[0].owner != self
            pdata = get_track(nil, :start)
            if pdata
                queue << pdata
            else
                return nil
            end
        end
        return do_prefetch_tracks(self.model, TTV_DATA, queue, max_entries)
    end

    def get_track(player_data, direction)
        return do_get_track(self, TTV_DATA, player_data, direction)
    end

end
