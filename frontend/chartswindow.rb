
class ChartsWindow < TopWindow

    include UIConsts

    VIEW_TRACKS    = 0
    VIEW_RECORDS   = 1
    VIEW_ARTISTS   = 2
    VIEW_COUNTRIES = 3
    VIEW_MTYPES    = 4
    VIEW_LABELS    = 5

    COUNT_PLAYED = 0
    COUNT_TIME   = 1

    COLUMNS_TITLES = ["Track", "Record", "Artist", "Country", "Genre"]
    COL_PIX_TITLES = ["Cover", "Cover", "Country", "", ""]

    COL_ENTRY  = 0
    COL_RANK   = 1
    COL_PIX    = 2
    COL_TEXT   = 3
    COL_PLAYED = 4
    COL_REF    = 5

    def initialize(mc)
        super(mc, UIConsts::CHARTS_WINDOW)

        @view_type  = VIEW_TRACKS
        @count_type = COUNT_PLAYED
        @filter = ""

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        @mc.glade[CHARTS_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE)
        @mc.glade[CHARTS_WINDOW].signal_connect("focus_in_event")  { |widget, event| @mc.filter_receiver = self; false }

        @mc.glade[CHARTS_MM_TRACKS].signal_connect(:activate)    { load_view(VIEW_TRACKS)    }
        @mc.glade[CHARTS_MM_RECORDS].signal_connect(:activate)   { load_view(VIEW_RECORDS)   }
        @mc.glade[CHARTS_MM_ARTISTS].signal_connect(:activate)   { load_view(VIEW_ARTISTS)   }
        @mc.glade[CHARTS_MM_MTYPES].signal_connect(:activate)    { load_view(VIEW_MTYPES)    }
        @mc.glade[CHARTS_MM_COUNTRIES].signal_connect(:activate) { load_view(VIEW_COUNTRIES) }
        @mc.glade[CHARTS_MM_LABELS].signal_connect(:activate)    { load_view(VIEW_LABELS)    }
        @mc.glade[CHARTS_MM_PLAYED].signal_connect(:activate)    { @count_type = COUNT_PLAYED; load_view(@view_type) }
        @mc.glade[CHARTS_MM_TIME].signal_connect(:activate)      { @count_type = COUNT_TIME;   load_view(@view_type) }
        @mc.glade[CHARTS_MM_CLOSE].signal_connect(:activate)     { @mc.notify_closed(self) }

        @mc.glade[CHARTS_PM_ENQUEUE].signal_connect(:activate)     { enqueue }
        @mc.glade[CHARTS_PM_ENQUEUEFROM].signal_connect(:activate) { enqueue_multiple_tracks }
        @mc.glade[CHARTS_PM_PLAYHISTORY].signal_connect(:activate) {
            if @view_type == VIEW_TRACKS
                PlayHistoryDialog.new.show_track(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
            else
                PlayHistoryDialog.new.show_record(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
            end
        }
        @mc.glade[CHARTS_PM_GENPL].signal_connect(:activate)    { generate_play_list }
        @mc.glade[CHARTS_PM_SHOWINDB].signal_connect(:activate) {
            case @view_type
                when VIEW_TRACKS  then @mc.select_track(@tvc.selection.selected[COL_REF])
                when VIEW_RECORDS then @mc.select_record(@tvc.selection.selected[COL_REF])
                when VIEW_ARTISTS then @mc.select_artist(@tvc.selection.selected[COL_REF])
            end
        }

        @mc.glade[CHARTS_TV].signal_connect(:button_press_event) { |widget, event| show_popup(widget, event) }

        srenderer = Gtk::CellRendererText.new()
        @tvc = @mc.glade[UIConsts::CHARTS_TV]
        # Columns: Entry, Rank, cover, title, played -- Hidden: rtrack
        @lsc = Gtk::ListStore.new(Integer, String, Gdk::Pixbuf, String, String, Integer)

        pix = Gtk::CellRendererPixbuf.new
        pixcol = Gtk::TreeViewColumn.new("Cover")
        pixcol.pack_start(pix, false)
        pixcol.set_cell_data_func(pix) { |column, cell, model, iter| cell.pixbuf = iter[COL_PIX] }

        trk_renderer = Gtk::CellRendererText.new
        trk_column = Gtk::TreeViewColumn.new("Track", trk_renderer)
        trk_column.set_cell_data_func(trk_renderer) { |col, renderer, model, iter| renderer.markup = iter[COL_TEXT] }

        @tvc.append_column(Gtk::TreeViewColumn.new("Entry", srenderer, :text => COL_ENTRY))
        @tvc.append_column(Gtk::TreeViewColumn.new("Rank", srenderer, :text => COL_RANK))
        @tvc.append_column(pixcol)
        @tvc.append_column(trk_column)
        @tvc.append_column(Gtk::TreeViewColumn.new("Played", srenderer, :text => COL_PLAYED))

        @tvc.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tvc.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            if [VIEW_TRACKS, VIEW_RECORDS].include?(@view_type)
                if @view_type == VIEW_TRACKS
                    selection_data.set(Gdk::Selection::TYPE_STRING, ":"+@tvc.selection.selected[COL_REF].to_s)
                else
                    tracks = ""
                    DBIntf::connection.execute("SELECT rtrack FROM tracks WHERE rrecord=#{@tvc.selection.selected[COL_REF]};") { |row| tracks += ":"+row[0].to_s }
                    selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
                end
            end
        }

        @tvc.columns[COL_TEXT].resizable = true

        @tvc.model = @lsc
    end

    def show_popup(widget, event)
        return if [VIEW_COUNTRIES, VIEW_MTYPES, VIEW_LABELS].include?(@view_type) # No possible action
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            @mc.glade[CHARTS_PM_ENQUEUE].sensitive = @view_type != VIEW_ARTISTS
            @mc.glade[CHARTS_PM_ENQUEUEFROM].sensitive = @view_type == VIEW_TRACKS
            @mc.glade[CHARTS_PM_GENPL].sensitive = @view_type == VIEW_TRACKS
            @mc.glade[CHARTS_PM_PLAYHISTORY].sensitive = @view_type != VIEW_ARTISTS
            @mc.glade[CHARTS_PM].popup(nil, nil, event.button, event.time)
        end
    end

    def show_history
        PlayHistoryDialog.new(self).show_track(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
    end

    def enqueue
        if @view_type == VIEW_TRACKS
            @mc.pqueue.enqueue(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
        else
            DBIntf::connection.execute("SELECT rtrack FROM tracks WHERE rrecord=#{@tvc.selection.selected[COL_REF]};") do |row|
                @mc.pqueue.enqueue(row[0])
            end
        end
    end

    def enqueue_multiple_tracks
        return if @tvc.selection.selected.nil?
        selection = @tvc.selection.selected.path.to_s.to_i
        @lsc.each { |mode, path, iter| @mc.pqueue.enqueue(iter[COL_REF]) if path.to_s.to_i >= selection }
    end

    def live_update(rtrack)
        #update_view(@view_type)
        # Get the appropriate (track, record or artist) reference from the track reference
        ref = case @view_type
            when VIEW_TRACKS
                rtrack
            when VIEW_RECORDS
                DBIntf::connection.get_first_value("SELECT rrecord FROM tracks WHERE rtrack=#{rtrack};")
            when VIEW_ARTISTS
                DBIntf::connection.get_first_value("SELECT segments.rartist FROM segments INNER JOIN tracks ON tracks.rsegment=segments.rsegment " \
                                                   "WHERE tracks.rtrack=#{rtrack};")
            when VIEW_COUNTRIES
                DBIntf::connection.get_first_value("SELECT artists.rorigin FROM artists " \
                                                   "INNER JOIN segments ON artists.rartist=segments.rartist " \
                                                   "INNER JOIN tracks ON tracks.rsegment=segments.rsegment " \
                                                   "WHERE tracks.rtrack=#{rtrack};")
            when VIEW_MTYPES
                DBIntf::connection.get_first_value("SELECT records.rgenre FROM records INNER JOIN tracks ON tracks.rrecord=records.rrecord " \
                                                   "WHERE tracks.rtrack=#{rtrack};")
            when VIEW_LABELS
                DBIntf::connection.get_first_value("SELECT records.rlabel FROM records INNER JOIN tracks ON tracks.rrecord=records.rrecord " \
                                                   "WHERE tracks.rtrack=#{rtrack};")
        end

        load_view(@view_type, ref)

        itr = nil
        @lsc.each { |model, path, iter| if iter[COL_REF] == ref then itr = iter; break; end }
        @tvc.set_cursor(itr.path, nil, false) unless itr.nil?
    end

    def set_filter(where_clause, must_join_logtracks = false)
        @filter = where_clause
        load_view(@view_type, -1)
    end
    
#     def set_filter
#         # Condition is inverted because the signal is received before the action takes place
#         @filter = @mc.glade[CHARTS_MM_FILTER].active? ? @mc.filter.generate_filter(true) : ""
#         load_view(@view_type, -1)
# #         flt_gen = FilterGeneratorDialog.new
# #         if flt_gen.show(FilterGeneratorDialog::MODE_FILTER) == Gtk::Dialog::RESPONSE_OK
# #             @filter = flt_gen.get_filter(true)
# #             load_view(@view_type, -1)
# #         end
# #         flt_gen.destroy
#     end

    def generate_play_list
        rplist = DBUtils::get_last_id("plist")+1
        DBIntf::connection.execute("INSERT INTO plists VALUES (#{rplist}, 'Charts generated', 1, #{Time.now.to_i}, 0);")
        rpltrack = DBUtils::get_last_id("pltrack")
        count = 1
        @lsc.each { |model, path, iter|
            DBIntf::connection.execute("INSERT INTO pltracks VALUES (#{rpltrack+count}, #{rplist}, #{iter[COL_REF]}, #{count});")
            count += 1
        }
    end

    def generate_sql
        # The sql statement must return played in the first col and the ref to the table in the second col
        #
        # N.B: le join sur les records dans les vues par artiste et pays est necessaire si on utilise le filtre!!!
        #      (Juste pour me rappeler pourquoi je me demande pourquoi j'ai foutu ça alors qu'à priori y'a pas besoin)
        #
		field = @count_type == COUNT_TIME ? "SUM(tracks.iplaytime)" : "COUNT(logtracks.rlogtrack)"
		field += " AS totplayed"
        case @view_type
            when VIEW_TRACKS
#                 sql = %Q{SELECT #{field}, tracks.rtrack, tracks.rrecord, records.irecsymlink,
#                         FROM tracks
# 						INNER JOIN records ON tracks.rrecord=records.rrecord
# 						INNER JOIN artists ON artists.rartist=records.rartist
# 						INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
# 						WHERE tracks.iplayed > 0 }
                sql = %Q{SELECT #{field}, tracks.rtrack, tracks.rrecord, records.irecsymlink, tracks.stitle,
                                segments.stitle, records.stitle, artists.sname, tracks.isegorder
                        FROM tracks
                        INNER JOIN segments ON tracks.rsegment=segments.rsegment
                        INNER JOIN records ON tracks.rrecord=records.rrecord
                        INNER JOIN artists ON artists.rartist=segments.rartist
                        INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 }
                group_by = "tracks.rtrack"
            when VIEW_RECORDS
                sql = "SELECT #{field}, records.rrecord, records.stitle, records.irecsymlink, artists.sname FROM tracks " \
                      "INNER JOIN records ON tracks.rrecord=records.rrecord " \
                      "INNER JOIN artists ON artists.rartist=records.rartist " \
		       "INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack " \
                      "WHERE tracks.iplayed > 0 "
                group_by = "records.rrecord"
            when VIEW_ARTISTS
                sql = "SELECT #{field}, artists.rartist, artists.sname, artists.rorigin FROM tracks " \
                      "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                      "INNER JOIN artists ON artists.rartist=segments.rartist " \
                      "INNER JOIN records ON tracks.rrecord=records.rrecord " \
		       "INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack " \
                      "WHERE tracks.iplayed > 0 "
                group_by = "artists.rartist"
            when VIEW_COUNTRIES
                sql = "SELECT #{field}, origins.rorigin, origins.sname FROM tracks " \
                      "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                      "INNER JOIN artists ON artists.rartist=segments.rartist " \
                      "INNER JOIN records ON tracks.rrecord=records.rrecord " \
                      "INNER JOIN origins ON origins.rorigin=artists.rorigin " \
		       "INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack " \
                      "WHERE tracks.iplayed > 0 " #AND origins.rorigin > 0 "
                group_by = "artists.rorigin"
            when VIEW_MTYPES
                sql = "SELECT #{field}, genres.rgenre, genres.sname FROM tracks " \
                      "INNER JOIN records ON tracks.rrecord=records.rrecord " \
                      "INNER JOIN genres ON records.rgenre=genres.rgenre " \
		       "INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack " \
                      "WHERE tracks.iplayed > 0 " #AND records.rgenre > 0 "
                group_by = "records.rgenre"
            when VIEW_LABELS
                sql = %Q{SELECT #{field}, labels.rlabel, labels.sname FROM tracks
                           INNER JOIN records ON tracks.rrecord=records.rrecord
                             INNER JOIN labels ON records.rlabel=labels.rlabel
                               INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                         WHERE tracks.iplayed > 0 }
                group_by = "records.rlabel"
        end
        sql += @filter unless @filter.empty?
        sql += "GROUP BY #{group_by} ORDER BY totplayed DESC LIMIT #{Cfg::instance.max_items};"
# p sql
        return  sql
    end

    def load_view(view_type, ref = -1)
        if view_type != @view_type
            @tvc.columns[COL_PIX].visible = view_type != VIEW_MTYPES && view_type != VIEW_LABELS
            @tvc.columns[COL_TEXT].title = COLUMNS_TITLES[view_type]
            @tvc.columns[COL_PIX].title = COL_PIX_TITLES[view_type]
            @view_type = view_type
        end


        @lsc.clear if ref == -1

        found = can_exit = first_match = false
        i = rank = 0
        last_played = -1
#RubyProf.start
        DBIntf::connection.execute(generate_sql) do |row|
            i += 1
            if ref == -1
                iter = @lsc.append
            else
                if !found
                    next if row[1] != ref
                    found = first_match = true
                    iter = @lsc.get_iter((i-1).to_s)
                    can_exit = iter[COL_REF] == ref
                else
                    iter = @lsc.get_iter((i-1).to_s)
                end
            end

            played = row[0].to_i
            if played != last_played
                rank = i
                last_played = played
            end
            if first_match
                first_match = false
                rank = @lsc.get_iter((i-2).to_s)[COL_RANK] if i > 1 && played.to_s == @lsc.get_iter((i-2).to_s)[COL_PLAYED]
            end

            iter[COL_ENTRY] = i
            iter[COL_RANK] = rank.to_s
            if @count_type == COUNT_PLAYED
                iter[COL_PLAYED] = played.to_s
            else
                if @view_type == VIEW_TRACKS || @view_type == VIEW_RECORDS
                    iter[COL_PLAYED] = Utils::format_hr_length(played)
                else
                    iter[COL_PLAYED] = Utils::format_day_length(played)
                end
            end
            iter[COL_REF] = row[1]
            case view_type
                when VIEW_TRACKS
                    iter[COL_PIX]  = IconsMgr::instance.get_cover(row[2], iter[COL_REF], row[3], 64)
                    iter[COL_TEXT] = UIUtils::full_html_track_title(
                                        Utils::make_track_title(0, row[4], row[8], row[5], @mc.show_segment_title?),
                                        row[7], row[6])
                when VIEW_RECORDS
                    iter[COL_PIX]  = IconsMgr::instance.get_cover(row[1], 0, row[3], 64)
                    iter[COL_TEXT] = "<b>"+CGI::escapeHTML(row[2])+"</b>\n"+
                                     "by <i>"+CGI::escapeHTML(row[4])+"</i>"
                when VIEW_ARTISTS
                    iter[COL_PIX]  = IconsMgr::instance.get_flag(row[3], 16)
                    iter[COL_TEXT] = "<b>"+CGI::escapeHTML(row[2])+"</b>"
                when VIEW_COUNTRIES
                    iter[COL_PIX]  = IconsMgr::instance.get_flag(row[1], 16)
                    iter[COL_TEXT] = "<b>"+CGI::escapeHTML(row[2])+"</b>"
                when VIEW_MTYPES, VIEW_LABELS
                    iter[COL_TEXT] = "<b>"+CGI::escapeHTML(row[2])+"</b>"
            end
            break if can_exit
        end
#result = RubyProf.stop
#printer = RubyProf::FlatPrinter.new(result)
# f = File.new("../../chartsprofile.txt", "a+")
# printer.print(f, 0)
# f.close
#printer.print
        @tvc.columns_autosize if ref == -1
ref == -1 ? puts("*** charts full load done ***\n") : puts("*** charts update done ***\n")
    end

    def show
        load_view(@view_type) #if !Cfg::instance.live_charts_update? || @lsc.iter_first.nil?
        super
    end
end
