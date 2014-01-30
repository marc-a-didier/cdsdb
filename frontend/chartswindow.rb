
#
# From now the charts view is stored in an array that is used to feed the tree view
# because the fucking tree view model is unusable to fulfill my needs.
#
# The main advantage of this method is that i don't need to re-execute the sql query
# which takes a lot of time on each update. Times are directly set in the array and
# the view redrawn.
#
# But it has the drawbacks of a cache mechanism. As long as a full reload from the
# database is not made, changes in the database are not reflected in the charts.
#

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

    ChartEntry = Struct.new(:entry, :rank, :pix, :title, :ref, :played, :uilink)

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
                when VIEW_TRACKS  then @mc.select_track(entry_from_selection.uilink)
                when VIEW_RECORDS then @mc.select_record(entry_from_selection.uilink)
                when VIEW_ARTISTS then @mc.select_artist(@tvc.selection.selected[COL_REF])
            end
        }

        @mc.glade[CHARTS_TV].signal_connect(:button_press_event) { |widget, event| show_popup(widget, event) }

        srenderer = Gtk::CellRendererText.new()
        @tvc = @mc.glade[UIConsts::CHARTS_TV]
        # Columns: Entry, Rank, cover, title, played -- Hidden: ref
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

        @tvc.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tvc.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            if [VIEW_TRACKS, VIEW_RECORDS].include?(@view_type)
                selection_data.set(Gdk::Selection::TYPE_STRING, "charts:message:get_charts_selection")
            end
        }

        @tvc.columns[COL_TEXT].resizable = true

        @tvc.model = @lsc

        @entries = []
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

    def entry_from_selection
        return @entries[@tvc.selection.selected[COL_ENTRY]-1]
    end

    def show_history
        PlayHistoryDialog.new(self).show_track(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
    end

    def get_selection
        return [] if @tvc.selection.selected.nil?

        links = []
        ref = @tvc.selection.selected[COL_REF]
        if @view_type == VIEW_TRACKS
            links << @entries[@tvc.selection.selected[COL_ENTRY]-1].uilink.clone
        else
            sql = "SELECT rtrack FROM tracks WHERE rrecord=#{ref};"
            CDSDB.execute(sql) { |row| links << UILink.new.set_track_ref(row[0]) }
        end
        return links
    end

    def enqueue
        @mc.pqueue.enqueue(get_selection)
    end

    def enqueue_multiple_tracks
        return if @tvc.selection.selected.nil?

        selection = @tvc.selection.selected[COL_ENTRY]-1
        @entries.each { |entry|
            @mc.pqueue.enqueue([entry.uilink]) if entry.entry >= selection
            break if entry.entry >= CFG.max_items
        }
    end

    def live_update(uilink)
        # Get the appropriate (track, record or artist) reference from the track reference
        ref = case @view_type
            when VIEW_TRACKS
                uilink.track.rtrack
            when VIEW_RECORDS
                uilink.track.rrecord
            when VIEW_ARTISTS
                uilink.segment.rartist
            when VIEW_COUNTRIES
                uilink.artist.rorigin
            when VIEW_MTYPES
                uilink.record.rgenre
            when VIEW_LABELS
                uilink.record.rlabel
        end

        lazy_update(@view_type, ref, uilink.track)

        # Cannot use the if as a modifier, iter is considered as undeclared...
        if iter = @tvc.find_ref(ref, COL_REF)
            @tvc.set_cursor(iter.path, nil, false)
        end
    end


    def set_filter(where_clause, must_join_logtracks = false)
        @filter = where_clause
        load_view(@view_type)
    end

    #
    # Generates a play plist from the current chart.
    #
    def generate_play_list
        rplist = DBUtils::get_last_id("plist")+1
        CDSDB.execute("INSERT INTO plists VALUES (#{rplist}, 'Charts generated', 1, #{Time.now.to_i}, 0);")
        rpltrack = DBUtils::get_last_id("pltrack")
        count = 1
        @lsc.each { |model, path, iter|
            CDSDB.execute("INSERT INTO pltracks VALUES (#{rpltrack+count}, #{rplist}, #{iter[COL_REF]}, #{count*1024});")
            count += 1
        }
    end

    def generate_sql
        # The sql statement must return played in the first col and the ref to the table in the second col
        #
        # N.B: le join sur les records dans les vues par artiste et pays est necessaire si on utilise le filtre!!!
        #      (Juste pour me rappeler pourquoi je me demande pourquoi j'ai foutu ça alors qu'à priori y'a pas besoin)
        #
        field = @count_type == COUNT_TIME ? "SUM(tracks.iplaytime)" : "COUNT(logtracks.rtrack)"
        field += " AS totplayed"
        case @view_type
            when VIEW_TRACKS
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
#                 field = "(COUNT(logtracks.rtrack)/COUNT(tracks.rtrack)) AS totplayed" if @count_type == COUNT_PLAYED
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
        sql += "GROUP BY #{group_by} ORDER BY totplayed DESC LIMIT #{CFG.max_items+50};"
# p sql
        return  sql
    end

    #
    # Builds the cache array from the appropriate sql query
    #
    def load_charts
        @entries.clear
        i = rank = 0
        last_played = -1
        CDSDB.execute(generate_sql) do |row|
            entry = ChartEntry.new
            entry.entry = i
            entry.played = row[0].to_i
            entry.ref = row[1]
            i += 1
            if entry.played != last_played
                rank = i
                last_played = entry.played
            end
            entry.rank = rank

            # If view is other than tracks or record, the entry is fully loaded in this loop
            if ![VIEW_TRACKS, VIEW_RECORDS].include?(@view_type)
                entry.title = row[2].to_html_bold
                entry.pix   = IMG_CACHE.get_flag(row[3]) if @view_type == VIEW_ARTISTS
                entry.pix   = IMG_CACHE.get_flag(row[1]) if @view_type == VIEW_COUNTRIES
            end

            @entries << entry
        end

        # Done if not tracks or records charts
        return if ![VIEW_TRACKS, VIEW_RECORDS].include?(@view_type)

        # Pix and title loading are in another loop because making db accesses while reading
        # the result set of the query greatly speeds the things down...
        @entries.each { |entry|
            if @view_type == VIEW_TRACKS
                entry.uilink = UILink.new.set_track_ref(entry.ref)
                entry.pix     = entry.uilink.small_track_cover
                entry.title   = entry.uilink.html_track_title_no_track_num(@mc.show_segment_title?)
            else
                entry.uilink = UILink.new.set_record_ref(entry.ref)
                entry.pix     = entry.uilink.small_record_cover
                entry.title   = entry.uilink.html_record_title
            end
        }
    end

    #
    # Dumps the cache array into the tree view model.
    # If is_reload is true, iters are updated otherwise they're added.
    #
    def display_charts(is_reload)
        @entries.each_with_index { |entry, i|
            break if i == CFG.max_items
            iter = is_reload ? @lsc.get_iter(i.to_s) : @lsc.append
            iter[COL_ENTRY] = entry.entry+1
            iter[COL_RANK]  = entry.rank.to_s
            if @count_type == COUNT_PLAYED
                iter[COL_PLAYED] = entry.played.to_s
            else
                if [VIEW_TRACKS, VIEW_RECORDS].include?(@view_type)
                    iter[COL_PLAYED] = entry.played.to_hr_length
                else
                    iter[COL_PLAYED] = entry.played.to_day_length
                end
            end
            iter[COL_REF]  = entry.ref
            iter[COL_PIX]  = entry.pix
            iter[COL_TEXT] = entry.title
        }
    end

    #
    # Sets the columns titles and visibility and makes a snapshot of the database.
    #
    def load_view(view_type)
        if view_type != @view_type
            @tvc.columns[COL_PIX].visible = view_type != VIEW_MTYPES && view_type != VIEW_LABELS
            @tvc.columns[COL_TEXT].title = COLUMNS_TITLES[view_type]
            @tvc.columns[COL_PIX].title = COL_PIX_TITLES[view_type]
            @view_type = view_type
        end

        @lsc.clear

        load_charts
        display_charts(false)

        @tvc.columns_autosize
TRACE.debug("Charts full load done".red)
        return
#RubyProf.start
#result = RubyProf.stop
#printer = RubyProf::FlatPrinter.new(result)
# f = File.new("../../chartsprofile.txt", "a+")
# printer.print(f, 0)
# f.close
#printer.print
    end

    #
    # Lazy update works only for items already in charts. The cache has more items
    # than the view displays so it should be sufficient if a new track makes it
    # to the top.
    #
    def lazy_update(view_type, ref, track)
        pos = @entries.index { |ce| ce.ref == ref }
        return unless pos

        @entries[pos].played += @count_type == COUNT_PLAYED ? 1 : track.iplaytime
        @entries.sort! { |ce1, ce2| ce2.played <=> ce1.played }

        rank = pos = 0
        last_played = -1
        @entries.each_with_index { |entry, i|
            entry.entry = i
            if entry.played != last_played
                rank = i+1
                last_played = entry.played
            end
            entry.rank = rank
            pos = entry.entry if entry.ref == ref
        }
        display_charts(true) if pos < CFG.max_items
TRACE.debug("Charts lazy update done".green)
    end

    def show
        load_view(@view_type) #if !CFG.live_charts_update? || @lsc.iter_first.nil?
        super
    end
end
