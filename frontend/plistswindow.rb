
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

        @pt_changed = false # True if tracks play list has changed

        @mc.glade[UIConsts::PM_PL_SAVE].signal_connect(:activate)          { save_plt if @pt_changed }
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
        @mc.glade[UIConsts::PL_MB_SAVE].signal_connect(:activate)          { save_plt if @pt_changed }
        #@mc.glade[UIConsts::PL_MB_DELETE].signal_connect(:activate) { do_del }
        @mc.glade[UIConsts::PL_MB_INFOS].signal_connect(:activate)         { show_infos(false) }
#         @mc.glade[UIConsts::PL_MB_GENERATE].signal_connect(:activate)      { do_generate }
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
        @pts = Gtk::ListStore.new(Integer, Integer, Integer, String, String, String, String, Class)
        #col_names = ["Ref.", "Order", "Track", "Title", "By", "From", "Play time"]
        #col_names.size.times { |i|
        ["Ref.", "Order", "Track", "Title", "By", "From", "Play time"].each_with_index { |name, i|
            @tvpt.append_column(Gtk::TreeViewColumn.new(name, srenderer, :text => i))
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
            log_sql == true ? DBUtils::log_exec(sql) : DBIntf::connection.execute(sql)
        else
            DBUtils::client_sql(sql)
        end
    end

    def add_to_plist(rplist, rtrack)
        count = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM pltracks WHERE rplist=#{rplist} AND rtrack=#{rtrack};")
        count = 0 if count > 0 && UIUtils::get_response("This track is already in this play list. Add anyway?") == Gtk::Dialog::RESPONSE_OK
        if count == 0
            seq = DBIntf::connection.get_first_value("SELECT MAX(iorder) FROM pltracks WHERE rplist=#{rplist}").to_i+1
            exec_sql("INSERT INTO pltracks VALUES (#{DBUtils::get_last_id("pltrack")+1}, #{rplist}, #{rtrack}, #{seq});")
            exec_sql("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
            update_tvpt
        end
    end

    def on_drag_received(widget, context, x, y, data, info, time)
        # Returns directly if data don't come from a CDs DB browser
        if info != 700 || @tvpl.selection.selected.nil? #DragType::BROWSER_SELECTION
            Gtk::Drag.finish(context, false, false, Time.now.to_i)
            return false
        end

        sender, type, call_back = data.text.split(":")
        if sender == "plist" # -> reordering
#             iref = @tvpt.selection.selected[4].track.rtrack
            itr = find_ref(@tvpt.selection.selected[0])
#             @pts.each { |model, path, iter| if iter[TT_REF] == track.to_i then itr = iter; break end }
            if itr
                r = @tvpt.get_dest_row(x, y)
                if r.nil?
                    iter = @pts.append
                else
                    pos = r[0].to_s.to_i
                    pos += 1 if r[1] == Gtk::TreeView::DROP_AFTER || r[1] == Gtk::TreeView::DROP_INTO_OR_AFTER
                    iter = @pts.insert(pos)
                end
                @pts.n_columns.times { |i| iter[i] = itr[i] }
                @pts.remove(itr)
            end
        else
            @mc.send(call_back).each { |uilink|
                add_to_plist(@current_pl.rplist, uilink.track.rtrack)
            }
        end

        if sender == "plist" # Have to renumber because of a reordering
            renumber_tracks_list_store
            @pt_changed = true
        end

        Gtk::Drag.finish(context, true, false, Time.now.to_i)
        return true
    end

    def get_selection
        stores = []
        @tvpt.selection.selected_each { |model, path, iter| stores << iter[TT_DATA] }
        return stores
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
#         DBIntf::connection.execute(%Q{SELECT COUNT(pltracks.rtrack), SUM(tracks.iplaytime) FROM pltracks
#                                       LEFT OUTER JOIN tracks ON pltracks.rtrack = tracks.rtrack
#                                       WHERE rplist=#{@current_pl.rplist}}) do |row|
#             @tracks = row[0].to_i
#             @ttime = row[1].to_i
#         end
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
        @mc.update_track_icon(uilink.track.rtrack)
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

    def reset_player_track
        @curr_track = -1
        @playing_pl = 0
        plist_infos
    end

    def get_next_track
        if @curr_track == -1
            @tvpt.cursor.nil? ? @curr_track = 0 : @curr_track = @tvpt.cursor[0].to_s.to_i
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
        if is_next
            return !@pts.get_iter((@curr_track+1).to_s).nil?
        else
            return @curr_track-1 >= 0
        end
    end

    #
    #
    #

    def do_check_orphans
        p DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM pltracks where rplist=8;")
        p DBIntf::connection.get_first_value("SELECT COUNT(DISTINCT(rtrack)) FROM pltracks where rplist=8;")
        return
        @pts.each do |model, path, iter|
            row = DBIntf::connection.get_first_value("SELECT COUNT(rpltrack) FROM pltracks WHERE rtrack=#{iter[TT_DATA].track.rtrack};")
            p iter if row.nil?
        end
    end

    def renumber_tracks_list_store
        i = 0
        @pts.each { |model, path, iter| i += 1; iter[1] = i }
    end

    def on_pl_change
        return if @tvpl.selection.selected.nil?
        ask_save_if_changed
        reset_player_track
        @current_pl.ref_load(@tvpl.selection.selected[0])
        update_tvpt
    end

    def on_tv_edited(widget, path, new_text)
        return if @tvpl.selection.selected[1] == new_text
        exec_sql("UPDATE plists SET sname=#{new_text.to_sql}, idatemodified=#{Time.now.to_i} " \
                 "WHERE rplist=#{@current_pl.rplist};")
        @tvpl.selection.selected[1] = new_text
    end

    def save_plt
        @pts.each do |model, path, iter|
            #DBIntf::connection.execute("UPDATE pltracks SET iorder=#{iter[1]} WHERE rpltrack=#{iter[0]}")
            exec_sql("UPDATE pltracks SET iorder=#{iter[1]} WHERE rpltrack=#{iter[0]}")
        end
        exec_sql("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{@current_pl.rplist};")
        @pt_changed = false
    end

    def do_add
        exec_sql(%{INSERT INTO plists VALUES (#{DBUtils::get_last_id('plist')+1}, 'New Play List', 0, #{Time.now.to_i}, 0);})
        update_tvpl
    end

    def do_del(widget)
        # Check if the add item is sensitive to determinate if the popup is in the play lists or tracks
#         pltracks = []
        unless @mc.glade[UIConsts::PM_PL_ADD].sensitive?
#             @tvpt.selection.selected_each { |model, path, iter| pltracks << iter[0] }
#             pltracks.each { |rpltrack|
#                 @pts.each { |model, path, iter|
#                     next if iter[0] != rpltrack
#                     exec_sql("DELETE FROM pltracks WHERE rpltrack=#{rpltrack};")
#                     @remaining_time -= iter[TT_DATA].track.iplaytime if @curr_track != -1 && path.to_s.to_i > @curr_track
#                     @pts.remove(iter)
#                     break
#                 }
#             }
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
            do_renumber
            renumber_tracks_list_store
            update_tracks_time_infos
        else
            if UIUtils::get_response("This will remove the entire playlist! Process anyway?") == Gtk::Dialog::RESPONSE_OK
                exec_sql("DELETE FROM pltracks WHERE rplist=#{@current_pl.rplist};")
                exec_sql("DELETE FROM plists WHERE rplist=#{@current_pl.rplist};")
                update_tvpl
                update_tvpt
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
    end

    def do_renumber
        return if @tvpl.selection.selected.nil?
        DBUtils::renumber_play_list(@current_pl.rplist)
        MusicClient.new.renumber_play_list(@current_pl.rplist) if !local? && Cfg::instance.remote?
    end

    def enqueue_track
        @tvpt.selection.selected_each { |model, path, iter| @mc.pqueue.enqueue([iter[TT_DATA]]) }
    end

    def show_infos(is_popup)
        if is_popup
            if @mc.glade[UIConsts::PM_PL_ADD].sensitive?
                PListDialog.new(@current_pl.rplist).run if @tvpl.selection.selected
            else
                TrackEditor.new(@pts.get_iter(@tvpt.selection.selected_rows[0][TT_DATA]).track.rrtrack).run if @tvpt.selection.count_selected_rows > 0
            end
        else
            PListDialog.new(@current_pl.rplist).run if @tvpl.selection.selected
        end
    end

    def do_export_xspf

        # La version REXML marche pas parce que ce putain de moteur de merde fout un lf dans le tag location!!!
#         xdoc = REXML::Document.new << REXML::XMLDecl.new("1.0", "UTF-8", "no")
#         xdoc.add_element("playlist", {"version"=>"1", "xmlns"=>"http://xspf.org/ns/0/"})
#         xdoc.root.add_element("creator").text = "CDsDB #{Cdsdb::VERSION}"
#         tracklist = xdoc.root.add_element("trackList")
#         DBIntf::connection.execute("SELECT rtrack FROM pltracks WHERE rplist=#{@tvpl.selection.selected[0]} ORDER BY iorder;") do |row|
#             track_info = Utils::get_track_info(row[0].to_i)
#             audio_file = Utils::search_real_audio_file(track_info)
#             unless audio_file.empty?
#                 track = REXML::Element.new("track")
#                 track.add_element("location").text = URI::escape("file://"+audio_file)
#                 tracklist << track
#             end
#         end
#         fname = Cfg::instance.music_dir+"Playlists/"+@tvpl.selection.selected[1]+".cdsdb.xspf"
#         File.open(fname, "w") { |file| REXML::Formatters::Pretty.new.write_document(xdoc, file) }

        track_infos = TrackInfos.new

        xdoc = XML::Document.new
        xdoc.root = XML::Node.new("playlist")
        xdoc.root["version"] = "1";
        xdoc.root["xmlns"] = "http://xspf.org/ns/0/"
        xdoc.root << tracklist = XML::Node.new("trackList")
        DBIntf::connection.execute("SELECT rtrack FROM pltracks WHERE rplist=#{@current_pl.rplist} ORDER BY iorder;") do |row|
            track_infos.get_track_infos(row[0])
            audio_file = Utils::audio_file_exists(track_infos).file_name
            unless audio_file.empty?
                track = XML::Node.new("track")
                location = XML::Node.new("location") << URI::escape("file://"+audio_file)
                track << location
                tracklist << track
            end
        end
        #print xdoc.to_s
        fname = Cfg::instance.music_dir+"Playlists/"+@current_pl.sname+".cdsdb.xspf"
        xdoc.save(fname, :indent => true, :encoding => XML::Encoding::UTF_8)
    end

    def do_export_m3u
        file = File.new(Cfg::instance.music_dir+"Playlists/"+@current_pl.sname+".cdsdb.m3u", "w")
        file << "#EXTM3U\n"
        DBIntf::connection.execute("SELECT rtrack FROM pltracks WHERE rplist=#{@current_pl.rplist} ORDER BY iorder;") do |row|
            audio_file = Utils::audio_file_exists(Utils::get_track_info(row[0])).file_name
            file << audio_file+"\n" unless audio_file.empty?
        end
        file.close
    end

    def do_export_pls
        counter = 0
        track_infos = TrackInfos.new
        rplist = @current_pl.rplist
        file = File.new(Cfg::instance.music_dir+"Playlists/#{@current_pl.sname}.cdsdb.pls", "w")
        file << "[playlist]\n\n"
        DBIntf::connection.execute("SELECT rtrack FROM pltracks WHERE rplist=#{rplist} ORDER BY iorder;") do |row|
            counter += 1
            track_infos.get_track_infos(row[0])
            audio_file = Utils::audio_file_exists(track_infos).file_name
            file << "File#{counter}=#{URI::escape("file://"+audio_file)}\n" <<
                    "Title#{counter}=#{track_infos.title}\n" <<
                    "Length#{counter}=#{track_infos.length/1000}\n\n"
        end
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
        rplist = DBIntf::connection.get_first_value("SELECT rplist FROM pltracks WHERE rpltrack=#{rpltrack};")
        if sel_iter = @tvpl.find_ref(rplist)
            @tvpl.set_cursor(sel_iter.path, nil, false)
            @tvpt.set_cursor(sel_iter.path, nil, false) if sel_iter = @tvpt.find_ref(rpltrack)
        end
    end

    def update_tvpl
        @pls.clear
        DBIntf::connection.execute( "SELECT rplist, sname FROM plists" ) do |row|
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
        DBIntf::connection.execute(
            "SELECT * FROM pltracks WHERE rplist=#{@current_pl.rplist} ORDER BY iorder;") do |row|
                iter = @pts.append
                iter[TT_REF]   = row[TDB_RPLTRACK]
                iter[TT_ORDER] = row[TDB_IORDER]
                iter[TT_DATA]  = UILink.new.set_track_ref(row[TDB_RTRACK])
                iter[TT_TRACK] = iter[TT_DATA].track.iorder
                iter[TT_TITLE]  = iter[TT_DATA].segment.stitle.empty? ? iter[TT_DATA].track.stitle : iter[TT_DATA].segment.stitle+": "+iter[TT_DATA].track.stitle
                iter[TT_ARTIST] = iter[TT_DATA].segment_artist.sname
                iter[TT_RECORD] = iter[TT_DATA].record.stitle
                iter[TT_LENGTH] = iter[TT_DATA].track.iplaytime.to_ms_length
        end
        update_tracks_time_infos
        @tvpt.columns_autosize
    end

    def ask_save_if_changed
        if @pt_changed == true
            save_plt if UIUtils::get_response("Play list has been modified! Save changes?") == Gtk::Dialog::RESPONSE_OK
            @pt_changed = false
        end
    end

    def hide
        ask_save_if_changed
        super
    end

    def show
        update_tvpl
        super
    end

end
