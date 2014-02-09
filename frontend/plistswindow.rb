
class PListsWindow < TopWindow

private
    TT_REF    = 0
    TT_ORDER  = 1
    TT_TRACK  = 2
    TT_TITLE  = 3
    TT_ARTIST = 4
    TT_RECORD = 5
    TT_LENGTH = 6
    TT_DATA   = 7 # Stores the cache
    TT_IORDER = 8 # Stores iorder from db

    TDB_RPLTRACK = 0
    TDB_RPLIST   = 1
    TDB_RTRACK   = 2
    TDB_IORDER   = 3
    TDB_TORDER   = 4
    TDB_TTITLE   = 5
    TDB_STITLE   = 6
    TDB_RTITLE   = 7
    TDB_ARTISTS  = 8
    TDB_ILENGTH  = 9

public

    def initialize(mc)
        super(mc, UIConsts::PLISTS_WINDOW)

        @mc.glade[UIConsts::PM_PL_ADD].signal_connect(:activate)           { do_add }
        @mc.glade[UIConsts::PM_PL_DELETE].signal_connect(:activate)        { |widget| do_del(widget) }
        @mc.glade[UIConsts::PM_PL_INFOS].signal_connect(:activate)         { show_infos(true) }
        @mc.glade[UIConsts::PM_PL_EXPORT_XSPF].signal_connect(:activate)   { do_export_xspf }
        @mc.glade[UIConsts::PM_PL_EXPORT_M3U].signal_connect(:activate)    { do_export_m3u }
        @mc.glade[UIConsts::PM_PL_EXPORT_PLS].signal_connect(:activate)    { do_export_pls }
        @mc.glade[UIConsts::PM_PL_EXPORT_DEVICE].signal_connect(:activate) { do_export_to_device }
        @mc.glade[UIConsts::PM_PL_SHUFFLE].signal_connect(:activate)       { shuffle_play_list }
        @mc.glade[UIConsts::PM_PL_ENQUEUE].signal_connect(:activate)       { enqueue_track }
        @mc.glade[UIConsts::PM_PL_SHOWINBROWSER].signal_connect(:activate) {
            @mc.select_track(@pts.get_iter(@tvpt.selection.selected_rows[0])[TT_DATA])
        }

        @mc.glade[UIConsts::PL_MB_NEW].signal_connect(:activate)           { do_add }
        #@mc.glade[UIConsts::PL_MB_DELETE].signal_connect(:activate) { do_del }
        @mc.glade[UIConsts::PL_MB_INFOS].signal_connect(:activate)         { show_infos(false) }
        @mc.glade[UIConsts::PL_MB_EXPORT_XSPF].signal_connect(:activate)   { do_export_xspf }
        @mc.glade[UIConsts::PL_MB_EXPORT_M3U].signal_connect(:activate)    { do_export_m3u }
        @mc.glade[UIConsts::PL_MB_EXPORT_PLS].signal_connect(:activate)    { do_export_pls }
        @mc.glade[UIConsts::PL_MB_EXPORT_DEVICE].signal_connect(:activate) { do_export_to_device }
        @mc.glade[UIConsts::PL_MB_CLOSE].signal_connect(:activate)         { window.signal_emit(:delete_event, nil) }

        @mc.glade[UIConsts::PL_MB_SHUFFLE].signal_connect(:activate)   { shuffle_play_list }
        @mc.glade[UIConsts::PL_MB_RENUMBER].signal_connect(:activate)  { do_renumber }
        @mc.glade[UIConsts::PL_MB_CHKORPHAN].signal_connect(:activate) { do_check_orphans }

        edrenderer = Gtk::CellRendererText.new()
        edrenderer.editable = true
        edrenderer.signal_connect(:edited) { |widget, path, new_text| on_tv_edited(widget, path, new_text) }

        srenderer = Gtk::CellRendererText.new()
        trk_renderer = Gtk::CellRendererText.new
#         trk_column = Gtk::TreeViewColumn.new("Track", trk_renderer)
#         trk_column.set_cell_data_func(trk_renderer) { |col, renderer, model, iter| renderer.markup = iter[col] }

        @tvpl = @mc.glade[UIConsts::TV_PLISTS]
        @pls = Gtk::ListStore.new(Integer, String)
        @current_pl = PListDBClass.new

        @tvpl.append_column(Gtk::TreeViewColumn.new("Ref.", srenderer, :text => 0))
        @tvpl.append_column(Gtk::TreeViewColumn.new("Play lists", edrenderer, :text => 1))
        @tvpl.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, 1) }
        @pls.set_sort_column_id(1, Gtk::SORT_ASCENDING)
        @tvpl.columns[1].sort_indicator = Gtk::SORT_ASCENDING
        @tvpl.columns[1].clickable = true

        @tvpl.model = @pls

        @tvpl.signal_connect(:cursor_changed) { on_pl_change }

        @tvpt = @mc.glade[UIConsts::TV_PLTRACKS]
        @pts = Gtk::ListStore.new(Integer, Integer, Integer, String, String, String, String, Class, Integer)

        ["Ref.", "Order", "Track", "Title", "By", "From", "Play time"].each_with_index { |name, i|
            @tvpt.append_column(Gtk::TreeViewColumn.new(name, trk_renderer, :text => i))
            if i == 3 || i == 4
                @tvpt.columns[i].set_cell_data_func(trk_renderer) { |col, renderer, model, iter| renderer.markup = iter[i].to_s }
            end
            @tvpt.columns[i].resizable = true
            if i > 0
                @tvpt.columns[i].clickable = true
                @tvpt.columns[i].signal_connect(:clicked) { reorder_pltracks(i) }
            end
        }
        @tvpt.columns[TT_TRACK].visible = false # Hide the track order, screen space wasted...

        @tvpt.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, 0) }

        @tvpt.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_drag_received(widget, context, x, y, data, info, time) }
        dragtable = [ ["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700] ] #DragType::BROWSER_SELECTION
        @tvpt.enable_model_drag_dest(dragtable, Gdk::DragContext::ACTION_COPY)

        @tvpt.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tvpt.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            selection_data.set(Gdk::Selection::TYPE_STRING, "plist:message:get_plist_selection")
        }

        @tvpt.model = @pts
        @tvpt.selection.mode = Gtk::SELECTION_MULTIPLE

        # Status bar infos related vars
        @tracks = 0
        @ttime = 0
        @remaining_time = 0

        # Var to check if play list changed while playing to avoid to update tracks and time infos
        @playing_pl = 0

        # Threading problems...
        @audio_file = ""

        set_ref_column_visibility(@mc.glade[UIConsts::MM_VIEW_DBREFS].active?)

        reset_player_track
    end

    def show_popup(widget, event, is_play_list)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            @mc.glade[UIConsts::PM_PL_ADD].sensitive = is_play_list == 1
            @mc.glade[UIConsts::PM_PL_EXPORT_XSPF].sensitive = is_play_list == 1
            @mc.glade[UIConsts::PM_PL_EXPORT_M3U].sensitive = is_play_list == 1
            @mc.glade[UIConsts::PM_PL_EXPORT_PLS].sensitive = is_play_list == 1
            @mc.glade[UIConsts::PM_PL_ENQUEUE].sensitive = is_play_list == 0
            @mc.glade[UIConsts::PM_PL_SHOWINBROWSER].sensitive = is_play_list == 0
            @mc.glade[UIConsts::PM_PL].popup(nil, nil, event.button, event.time)
        end
    end

    def reload
        update_tvpl
    end

    def set_ref_column_visibility(is_visible)
        [@tvpl, @tvpt].each { |tv| tv.columns[0].visible = is_visible }
    end

    def local?
        return @current_pl.iislocal == 1
    end

    def exec_sql(sql, log_sql = true)
        if local?
            log_sql == true ? DBUtils::log_exec(sql) : CDSDB.execute(sql)
        else
            DBUtils::client_sql(sql)
        end
    end

    def add_to_plist(rplist, rtrack)
        count = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM pltracks WHERE rplist=#{rplist} AND rtrack=#{rtrack};")
        count = 0 if count > 0 && UIUtils::get_response("This track is already in this play list. Add anyway?") == Gtk::Dialog::RESPONSE_OK
        if count == 0
            seq = CDSDB.get_first_value("SELECT MAX(iorder) FROM pltracks WHERE rplist=#{rplist}").to_i+1
            exec_sql("INSERT INTO pltracks VALUES (#{DBUtils::get_last_id("pltrack")+1}, #{rplist}, #{rtrack}, #{seq});")
            exec_sql("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
            update_tvpt
            @mc.track_provider_changed(self)
        end
    end

    def selected_track
        return @tvpt.selection.count_selected_rows == 1 ? @tvpt.model.get_iter(@tvpt.selection.selected_rows[0]) : nil
    end

    def on_drag_received(widget, context, x, y, data, info, time)
        # Returns directly if data don't come from a CDs DB browser
        if info != 700 || @tvpl.selection.selected.nil? #DragType::BROWSER_SELECTION
            Gtk::Drag.finish(context, false, false, Time.now.to_i)
            return false
        end

        sender, type, call_back = data.text.split(":")
        if sender == "plist" # -> reordering
            # Won't work in case of multi-selection
            itr = selected_track
            if itr
                r = @tvpt.get_dest_row(x, y) # Returns [path, position]
                if r.nil?
                    iter = @pts.append
                    new_iorder = @pts.get_iter((iter.path.to_s.to_i-1).to_s)[TT_IORDER]+1024
puts("new=#{new_iorder}")                    
                else
                    pos = r[0].to_s.to_i
                    pos += 1 if r[1] == Gtk::TreeView::DROP_AFTER || r[1] == Gtk::TreeView::DROP_INTO_OR_AFTER
                    iter = @pts.insert(pos)
                    prev = pos == 0 ? nil : @pts.get_iter((pos-1).to_s)
                    succ = @pts.get_iter((pos+1).to_s) # succ can't be nil, handled by r.nil? test
                    new_iorder = prev.nil? ? succ[TT_IORDER]/2 : (succ[TT_IORDER]+prev[TT_IORDER])/2
p new_iorder                    
                end
                @pts.n_columns.times { |i| iter[i] = itr[i] }
                @pts.remove(itr)
                iter[TT_IORDER] = new_iorder
                exec_sql("UPDATE pltracks SET iorder=#{new_iorder} WHERE rpltrack=#{iter[0]};")
                
                renumber_tracks_list_store
            end
        else
            @mc.send(call_back).each { |uilink|
                add_to_plist(@current_pl.rplist, uilink.track.rtrack)
            }
        end

        Gtk::Drag.finish(context, true, false, Time.now.to_i)
        @mc.track_provider_changed(self)
        return true
    end

    def get_selection
        links = []
        @tvpt.selection.selected_each { |model, path, iter| links << iter[TT_DATA].clone }
        return links
    end

    def reorder_pltracks(col_id)
        if @pts.sort_column_id.nil?
            @pts.set_sort_column_id(1, Gtk::SORT_ASCENDING)
            @tvpt.columns[1].sort_indicator = Gtk::SORT_ASCENDING
        end

        order = @pts.sort_column_id[1]
        if col_id == @pts.sort_column_id[0]
            order == Gtk::SORT_ASCENDING ? order = Gtk::SORT_DESCENDING : order = Gtk::SORT_ASCENDING
        else
            @tvpt.columns[@pts.sort_column_id[0]].sort_indicator = nil
        end

        @tvpt.columns[col_id].sort_indicator = order
        @pts.set_sort_column_id(col_id, order)
        @mc.track_provider_changed(self)
    end

    #
    # Player related methods
    #

    def update_tracks_time_infos
        @tracks = @ttime = 0
        @pts.each { |model, path, iter|
            @tracks += 1
            @ttime += iter[TT_DATA].track.iplaytime
        }
        @current_pl.rplist == @playing_pl ? update_tracks_label : plist_infos
    end

    def plist_infos
        @mc.glade[UIConsts::PL_LBL_TRACKS].text = @tracks.to_s+" track".check_plural(@tracks)
        @mc.glade[UIConsts::PL_LBL_PTIME].text = @ttime.to_hr_length
        @mc.glade[UIConsts::PL_LBL_ETA].text = ""
    end

    def update_tracks_label
        @mc.glade[UIConsts::PL_LBL_TRACKS].text = "Track #{@curr_track+1} of #{@tracks}"
    end

    def update_ptime_label(rmg_time)
        @mc.glade[UIConsts::PL_LBL_PTIME].text = "#{rmg_time.to_hr_length} left of #{@ttime.to_hr_length}"
        @mc.glade[UIConsts::PL_LBL_ETA].text = Time.at(Time.now.to_i+rmg_time/1000).strftime("%a %d, %H:%M")
    end

    def timer_notification(ms_time)
        if @current_pl.rplist == @playing_pl
            ms_time == -1 ? plist_infos : update_ptime_label(@remaining_time-ms_time)
        end
    end

    def notify_played(player_data)
        #@curr_track += 1
    end

    def dwl_file_name_notification(uilink, file_name)
        @mc.audio_link_ok(uilink)
        @mc.track_provider_changed(self)
    end

    def get_audio_file
        while true
            iter = @pts.get_iter(@curr_track.to_s)
            if iter.nil?
                reset_player_track
                return nil
            end

            @tvpt.set_cursor(iter.path, nil, false)
            if iter[TT_DATA].get_audio_file(self, @mc.tasks) == AudioLink::NOT_FOUND
                @curr_track += 1
            else
                break
            end
        end

        while iter[TT_DATA].audio_status == AudioLink::ON_SERVER
            Gtk.main_iteration while Gtk.events_pending?
            sleep(0.1)
        end

        @remaining_time = 0
        @pts.each { |model, path, iter| @remaining_time += iter[TT_DATA].track.iplaytime if @curr_track <= path.to_s.to_i }
        update_tracks_label
        update_ptime_label(@remaining_time)
        return PlayerData.new(self, @curr_track, iter[TT_DATA])
    end

    # Return an array of PlayerData that's max_entries in size and contain the next
    # tracks to play.
    # player_data is the current top of stack track of the player
    def prefetch_tracks(player_data, max_entries)
        queue = []
        max_entries.times do |i|
            iter = @pts.get_iter((@curr_track+i+1).to_s)
            break if iter.nil?
            queue << PlayerData.new(self, @curr_track+i+1, iter[TT_DATA])
            # TODO: get_audio_file(iter)
        end
        return queue
    end

    def reset_player_track
        @curr_track = -1
        @playing_pl = 0
        plist_infos
    end

    def get_next_track
        if @curr_track == -1
            @curr_track = @tvpt.cursor.nil? ? 0 : @tvpt.cursor[0].to_s.to_i
            @playing_pl = @current_pl.rplist
        else
            @curr_track += 1
        end
        return get_audio_file
    end

    def get_prev_track
        @curr_track -= 1
        return get_audio_file
    end

    def has_more_tracks(is_next)
        return is_next ? !@pts.get_iter((@curr_track+1).to_s).nil? : @curr_track-1 >= 0
    end

    #
    #
    #

    def do_check_orphans
        @pts.each do |model, path, iter|
            row = CDSDB.get_first_value("SELECT COUNT(rpltrack) FROM pltracks WHERE rtrack=#{iter[TT_DATA].track.rtrack};")
            p iter if row.nil?
        end
    end

    def renumber_tracks_list_store
        i = 0
        @pts.each { |model, path, iter| i += 1; iter[1] = i }
    end

    def on_pl_change
        return if @tvpl.selection.selected.nil?
        reset_player_track
        @current_pl.ref_load(@tvpl.selection.selected[0])
        update_tvpt
        @mc.track_provider_changed(self)
    end

    def on_tv_edited(widget, path, new_text)
        return if @tvpl.selection.selected[1] == new_text
        exec_sql("UPDATE plists SET sname=#{new_text.to_sql}, idatemodified=#{Time.now.to_i} " \
                 "WHERE rplist=#{@current_pl.rplist};")
        @tvpl.selection.selected[1] = new_text
    end

    def do_add
        exec_sql(%{INSERT INTO plists VALUES (#{DBUtils::get_last_id('plist')+1}, 'New Play List', 0, #{Time.now.to_i}, 0);})
        update_tvpl
        @mc.track_provider_changed(self)
    end

    def do_del(widget)
        # Check if the add item is sensitive to determinate if the popup is in the play lists or tracks
        unless @mc.glade[UIConsts::PM_PL_ADD].sensitive?
            iters = []
            sql = "DELETE FROM pltracks WHERE rpltrack IN ("
            @tvpt.selection.selected_each { |model, path, iter| sql += iter[0].to_s+","; iters << iter }
            sql[-1] = ")"
            exec_sql(sql)
            iters.each { |iter|
                if @curr_track != 1
                    if iter.path.to_s.to_i > @curr_track
                        @remaining_time -= iter[TT_DATA].track.iplaytime
                    else
                        @curr_track -= 1
                    end
                end
                @pts.remove(iter)
            }
            renumber_tracks_list_store
            update_tracks_time_infos
            @mc.track_provider_changed(self)
        else
            if UIUtils::get_response("This will remove the entire playlist! Process anyway?") == Gtk::Dialog::RESPONSE_OK
                exec_sql("DELETE FROM pltracks WHERE rplist=#{@current_pl.rplist};")
                exec_sql("DELETE FROM plists WHERE rplist=#{@current_pl.rplist};")
                update_tvpl
                update_tvpt
                @mc.track_provider_changed(self)
            end
        end
    end

    def shuffle_play_list
        count = 0
        new_order = []
        @pts.each { |model, path, iter| new_order << count; count += 1 }
        return if count < 2
        new_order.shuffle!
        # ce putain de truc marche plus depuis qu'on peut trier les colonnes...!!!
        # Apres consultation de diverses doc, c'est impossible de remettre le sort a nil
        # une fois qu'on a selectionne une colonne... donc impossible!
        @curr_track = -1
        @tvpt.selection.unselect_path(@tvpt.cursor[0]) unless @tvpt.cursor.nil?
        @pts.reorder(new_order) # It's magic!
        @mc.track_provider_changed(self)
    end

    def do_renumber
        return if @tvpl.selection.selected.nil?
        DBUtils::renumber_play_list(@current_pl.rplist)
        MusicClient.new.renumber_play_list(@current_pl.rplist) if !local? && CFG.remote?
    end

    def enqueue_track
        @tvpt.selection.selected_each { |model, path, iter| @mc.pqueue.enqueue([iter[TT_DATA]]) }
        @mc.track_provider_changed(self)
    end

    def show_infos(is_popup)
        if is_popup
            if @mc.glade[UIConsts::PM_PL_ADD].sensitive?
                PListDialog.new(@current_pl.rplist).run if @tvpl.selection.selected
            else
                iter = @tvpt.selection.count_selected_rows > 0 ? @pts.get_iter(@tvpt.selection.selected_rows[0]) : nil
                DBEditor.new(@mc, iter[TT_DATA], DBEditor::TRACK_PAGE).run if iter
            end
        else
            PListDialog.new(@current_pl.rplist).run if @tvpl.selection.selected
        end
    end

    def do_export_xspf
        xdoc = REXML::Document.new << REXML::XMLDecl.new("1.0", "UTF-8", "no")
        
        xdoc.add_element("playlist", {"version"=>"1", "xmlns"=>"http://xspf.org/ns/0/"})
        xdoc.root.add_element("creator").text = "CDsDB #{Cdsdb::VERSION}"
        tracklist = xdoc.root.add_element("trackList")
        
        @pts.each { |model, path, iter|
            next if iter[TT_DATA].setup_audio_file == AudioLink::NOT_FOUND
            track = REXML::Element.new("track")
            # In xspf specs, file name must be URI style formatted.
            track.add_element("location").text = URI::escape("file://"+iter[TT_DATA].audio_file)
            tracklist << track
        }
        
        fname = CFG.music_dir+"Playlists/"+@current_pl.sname+".cdsdb.xspf"
        File.open(fname, "w") { |file| MyFormatter.new.write(xdoc, file) }
    end

    def do_export_m3u
        file = File.new(CFG.music_dir+"Playlists/"+@current_pl.sname+".cdsdb.m3u", "w")
        file << "#EXTM3U\n"
        @pts.each { |model, path, iter|
            file << iter[TT_DATA].audio_file+"\n" unless iter[TT_DATA].setup_audio_file == AudioLink::NOT_FOUND
        }
        file.close
    end

    def do_export_pls
        counter = 0
        file = File.new(CFG.music_dir+"Playlists/#{@current_pl.sname}.cdsdb.pls", "w")
        file << "[playlist]\n\n"
        @pts.each { |model, path, iter|
            next if iter[TT_DATA].setup_audio_file == AudioLink::NOT_FOUND
            counter += 1
            file << "File#{counter}=#{URI::escape("file://"+iter[TT_DATA].audio_file)}\n" <<
                    "Title#{counter}=#{iter[TT_DATA].track.stitle}\n" <<
                    "Length#{counter}=#{iter[TT_DATA].track.ilength/1000}\n\n"
        }
        file << "NumberOfEntries=#{counter}\n\n" << "Version=2\n"
        file.close
    end

    def do_export_to_device
        dlg = ExportDialog.new
        exp = ExportParams.new
        return if dlg.run(exp) == Gtk::Dialog::RESPONSE_CANCEL # Run is auto-destroying

        track_infos = TrackInfos.new
        @pts.each { |model, path, iter|
            track_infos.get_track_infos(iter[TT_DATA].track.rtrack)
            audio_file = Utils::audio_file_exists(track_infos).file_name
            dest_file = exp.remove_genre ? audio_file.sub(/^#{exp.src_folder}[0-9A-Za-z ']*\//, exp.dest_folder) : audio_file.sub(/^#{exp.src_folder}/, exp.dest_folder)
            dest_file = dest_file.make_fat_compliant if exp.fat_compat
            if File.exists?(dest_file)
                puts "Export: file #{dest_file} already exists."
            else
                puts "Export: copying #{audio_file} to #{dest_file}"
                File.mkpath(File.dirname(dest_file))
                file_size = File.size(audio_file)
                curr_size = 0
                inf  = File.new(audio_file, "rb")
                outf = File.new(dest_file, "wb")
                dl_id = @mc.tasks.new_upload(File.basename(audio_file))
                while (data = inf.read(128*1024))
                    curr_size += data.size
                    @mc.tasks.update_file_op(dl_id, curr_size, file_size)
                    outf.write(data)
                    Gtk.main_iteration while Gtk.events_pending?
                end
                @mc.tasks.end_file_op(dl_id, audio_file)
            end
        }
    end

    def position_browser(rpltrack)
        rplist = CDSDB.get_first_value("SELECT rplist FROM pltracks WHERE rpltrack=#{rpltrack};")
        if sel_iter = @tvpl.find_ref(rplist)
            @tvpl.set_cursor(sel_iter.path, nil, false)
            @tvpt.set_cursor(sel_iter.path, nil, false) if sel_iter = @tvpt.find_ref(rpltrack)
            @mc.track_provider_changed(self)
        end
    end

    def update_tvpl
        @pls.clear
        CDSDB.execute( "SELECT rplist, sname FROM plists" ) do |row|
            iter = @pls.append
            iter[0] = row[0]
            iter[1] = row[1]
        end
    end

    def update_tvpt
        #reset_player_track
        @pts.clear
        return if @tvpl.cursor[0].nil?

        # The cache mechanism slows the things a bit down when a play list
        # is loaded for the first time
        CDSDB.execute(
            "SELECT * FROM pltracks WHERE rplist=#{@current_pl.rplist} ORDER BY iorder;") do |row|
                iter = @pts.append
                iter[TT_REF]   = row[TDB_RPLTRACK]
                iter[TT_ORDER] = iter.path.to_s.to_i+1
                iter[TT_IORDER] = row[TDB_IORDER]
                iter[TT_DATA]  = UILink.new.set_track_ref(row[TDB_RTRACK])
                iter[TT_TRACK] = iter[TT_DATA].track.iorder
                if iter[TT_DATA].segment.stitle.empty?
                    iter[TT_TITLE] = iter[TT_DATA].track.stitle.to_html_bold
                else
                    iter[TT_TITLE] = iter[TT_DATA].segment.stitle.to_html_bold+": "+iter[TT_DATA].track.stitle.to_html_bold
                end
                iter[TT_ARTIST] = iter[TT_DATA].segment_artist.sname.to_html_italic
                iter[TT_RECORD] = iter[TT_DATA].record.stitle
                iter[TT_LENGTH] = iter[TT_DATA].track.iplaytime.to_ms_length
        end
        update_tracks_time_infos
        @tvpt.columns_autosize
    end

    def show
        update_tvpl
        super
    end

end
