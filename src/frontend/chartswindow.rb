
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

    include GtkIDs

    VIEW_TRACKS       = 0
    VIEW_RECORDS_ABS  = 1
    VIEW_ARTISTS      = 2
    VIEW_COUNTRIES    = 3
    VIEW_MTYPES       = 4
    VIEW_LABELS       = 5
    VIEW_RECORDS_FULL = 6

    COUNT_PLAYED = 0
    COUNT_TIME   = 1

    COLUMNS_TITLES = ["Track", "Record", "Artist", "Country", "Genre"]
    COL_PIX_TITLES = ["Cover", "Cover", "Country", "", ""]

    COL_RANK   = 0
    COL_PLAYED = 1
    COL_PIX    = 2
    COL_TEXT   = 3
    COL_REF    = 4

    ChartEntry = Struct.new(:rank, :played, :pix, :title, :ref, :xlink)

    def initialize(mc)
        super(mc, CHARTS_WINDOW)

        @view_type  = VIEW_TRACKS
        @count_type = COUNT_PLAYED
        @filter = ""

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        GtkUI[CHARTS_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE)
        GtkUI[CHARTS_WINDOW].signal_connect("focus_in_event")  { |widget, event| @mc.filter_receiver = self; false }

        GtkUI[CHARTS_MM_TRACKS].signal_connect(:activate)       { |widget| load_view(VIEW_TRACKS,       widget) }
        GtkUI[CHARTS_MM_RECORDS_ABS].signal_connect(:activate)  { |widget| load_view(VIEW_RECORDS_ABS,  widget) }
        GtkUI[CHARTS_MM_RECORDS_FULL].signal_connect(:activate) { |widget| load_view(VIEW_RECORDS_FULL, widget) }
        GtkUI[CHARTS_MM_ARTISTS].signal_connect(:activate)      { |widget| load_view(VIEW_ARTISTS,      widget) }
        GtkUI[CHARTS_MM_MTYPES].signal_connect(:activate)       { |widget| load_view(VIEW_MTYPES,       widget) }
        GtkUI[CHARTS_MM_COUNTRIES].signal_connect(:activate)    { |widget| load_view(VIEW_COUNTRIES,    widget) }
        GtkUI[CHARTS_MM_LABELS].signal_connect(:activate)       { |widget| load_view(VIEW_LABELS,       widget) }

        GtkUI[CHARTS_MM_PLAYED].signal_connect(:activate) do |widget|
            @count_type = COUNT_PLAYED
            load_view(@view_type, widget)
        end
        GtkUI[CHARTS_MM_TIME].signal_connect(:activate)   do |widget|
            @count_type = COUNT_TIME
            load_view(@view_type, widget)
        end

        GtkUI[CHARTS_MM_CLOSE].signal_connect(:activate) { @mc.notify_closed(self) }

        GtkUI[CHARTS_PM_ENQUEUE].signal_connect(:activate)     { enqueue }
        GtkUI[CHARTS_PM_ENQUEUEFROM].signal_connect(:activate) { enqueue_multiple_tracks }
        GtkUI[CHARTS_PM_PLAYHISTORY].signal_connect(:activate) do
            if @view_type == VIEW_TRACKS
                Dialogs::PlayHistory.show_track(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
            else
                Dialogs::PlayHistory.show_record(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
            end
        end
        GtkUI[CHARTS_PM_GENPL].signal_connect(:activate)    { generate_play_list }
        GtkUI[CHARTS_PM_SHOWINDB].signal_connect(:activate) do
            case @view_type
                when VIEW_TRACKS       then @mc.select_track(entry_from_selection.xlink)
                when VIEW_RECORDS_ABS  then @mc.select_record(entry_from_selection.xlink)
                when VIEW_RECORDS_FULL then @mc.select_record(entry_from_selection.xlink)
                when VIEW_ARTISTS      then @mc.select_artist(@tvc.selection.selected[COL_REF])
            end
        end

        GtkUI[CHARTS_TV].signal_connect(:button_press_event) { |widget, event| show_popup(widget, event) }

        srenderer = Gtk::CellRendererText.new()
        @tvc = GtkUI[CHARTS_TV]
        @lsc = Gtk::ListStore.new(Integer, String, Gdk::Pixbuf, String, Integer)

        pix = Gtk::CellRendererPixbuf.new
        pixcol = Gtk::TreeViewColumn.new("Cover")
        pixcol.pack_start(pix, false)
        pixcol.set_cell_data_func(pix) { |column, cell, model, iter| cell.pixbuf = iter[COL_PIX] }

        trk_renderer = Gtk::CellRendererText.new
        trk_column = Gtk::TreeViewColumn.new("Track", trk_renderer)
        trk_column.set_cell_data_func(trk_renderer) { |col, renderer, model, iter| renderer.markup = iter[COL_TEXT] }

        @tvc.append_column(Gtk::TreeViewColumn.new("Rank", srenderer, :text => COL_RANK))
        @tvc.append_column(Gtk::TreeViewColumn.new("Played", srenderer, :text => COL_PLAYED))
        @tvc.append_column(pixcol)
        @tvc.append_column(trk_column)

        @tvc.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tvc.signal_connect(:drag_data_get) do |widget, drag_context, selection_data, info, time|
            if view_tracks_or_records?
                selection_data.set(Gdk::Selection::TYPE_STRING, "charts:message:get_charts_selection")
            end
        end

        @tvc.columns[COL_TEXT].resizable = true

        @tvc.model = @lsc

        @entries = []
    end

    def show_popup(widget, event)
        return if [VIEW_COUNTRIES, VIEW_MTYPES, VIEW_LABELS].include?(@view_type) # No possible action
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            GtkUI[CHARTS_PM_ENQUEUE].sensitive = @view_type != VIEW_ARTISTS
            GtkUI[CHARTS_PM_ENQUEUEFROM].sensitive = @view_type == VIEW_TRACKS
            GtkUI[CHARTS_PM_GENPL].sensitive = @view_type == VIEW_TRACKS
            GtkUI[CHARTS_PM_PLAYHISTORY].sensitive = @view_type != VIEW_ARTISTS
            GtkUI[CHARTS_PM].popup(nil, nil, event.button, event.time)
        end
    end

    def view_tracks_or_records?
        return [VIEW_TRACKS, VIEW_RECORDS_ABS, VIEW_RECORDS_FULL].include?(@view_type)
    end

    def entry_from_selection
        return @entries[@tvc.selection.selected.to_s.to_i]
    end

    def show_history
        Dialogs::PlayHistory.show_track(@tvc.selection.selected[COL_REF]) unless @tvc.selection.selected.nil?
    end

    def get_selection
        return [] if @tvc.selection.selected.nil?

        links = []
        ref = @tvc.selection.selected[COL_REF]
        if @view_type == VIEW_TRACKS
            links << entry_from_selection.xlink #.clone
        else
            sql = "SELECT rtrack FROM tracks WHERE rrecord=#{ref};"
            DBIntf.execute(sql) { |row| links << XIntf::Link.new.set_track_ref(row[0]).set_use_of_record_gain }
        end
        return links
    end

    def enqueue
        @mc.pqueue.enqueue(get_selection)
    end

    def enqueue_multiple_tracks
        return if @tvc.selection.selected.nil?

        # Changed the behavior because call to pqueue.enqueue now notifies
        # the mc that the pq has changed which in turn tells the player that
        # it needs to be refetched.
        # By calling enqueue only once with all links it reduce all the
        # messaging system to only one call.
        links = []
        selection = entry_from_selection #@tvc.selection.selected[COL_ENTRY]-1
        @entries.each_with_index do |entry, i|
            links << entry.xlink if i >= selection
            break if i >= Cfg.max_items
        end
        @mc.pqueue.enqueue(links)
    end

    def live_update(xlink)
        # Get the appropriate (track, record or artist) reference from the track reference
        ref = case @view_type
            when VIEW_TRACKS
                xlink.track.rtrack
            when VIEW_RECORDS_ABS, VIEW_RECORDS_FULL
                xlink.track.rrecord
            when VIEW_ARTISTS
                xlink.segment.rartist
            when VIEW_COUNTRIES
                xlink.artist.rorigin
            when VIEW_MTYPES
                xlink.record.rgenre
            when VIEW_LABELS
                xlink.record.rlabel
        end

        lazy_update(@view_type, ref, xlink.track)

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
        rplist = DBUtils.get_last_id("plist")+1
        DBIntf.execute("INSERT INTO plists VALUES (#{rplist}, 'Charts generated', 1, #{Time.now.to_i}, 0);")
        rpltrack = DBUtils.get_last_id("pltrack")
        count = 1
        @lsc.each do |model, path, iter|
            DBIntf.execute("INSERT INTO pltracks VALUES (#{rpltrack+count}, #{rplist}, #{iter[COL_REF]}, #{count*1024});")
            count += 1
        end
    end

    def generate_sql
        # The sql statement must return played in the first col and the ref to the table in the second col
        #
        # N.B: le join sur les records dans les vues par artiste et pays est necessaire si on utilise le filtre!!!
        #      (Juste pour me rappeler pourquoi je me demande pourquoi j'ai foutu ça alors qu'à priori y'a pas besoin)
        #
        if @view_type == VIEW_RECORDS_FULL
            field = @count_type == COUNT_TIME ? "MIN(tracks.iplayed)*records.iplaytime" : "MIN(tracks.iplayed)"
        else
            field = @count_type == COUNT_TIME ? "SUM(tracks.iplaytime)" : "COUNT(logtracks.rtrack)"
        end
        field += " AS totplayed"
        case @view_type
            when VIEW_TRACKS
                sql = %{SELECT #{field}, tracks.rtrack, tracks.rrecord, records.irecsymlink, tracks.stitle,
                                segments.stitle, records.stitle, artists.sname, tracks.isegorder
                        FROM tracks
                            INNER JOIN segments ON tracks.rsegment=segments.rsegment
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN artists ON artists.rartist=segments.rartist
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 }
                group_by = "tracks.rtrack"
            when VIEW_RECORDS_ABS
                sql = %{SELECT #{field}, records.rrecord, records.stitle, records.irecsymlink, artists.sname FROM tracks
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN artists ON artists.rartist=records.rartist
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 }
                group_by = "records.rrecord"
            when VIEW_RECORDS_FULL
                sql = %{SELECT #{field}, records.rrecord, records.stitle, records.irecsymlink, artists.sname FROM tracks
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN artists ON artists.rartist=records.rartist
                            LEFT JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE 1 = 1 } # Special WHERE clause cause must be a where if a filter is applied
                group_by = "records.rrecord"
            when VIEW_ARTISTS
                sql = %{SELECT #{field}, artists.rartist, artists.sname, artists.rorigin FROM tracks
                            INNER JOIN segments ON tracks.rsegment=segments.rsegment
                            INNER JOIN artists ON artists.rartist=segments.rartist
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 }
                group_by = "artists.rartist"
            when VIEW_COUNTRIES
                sql = %{SELECT #{field}, origins.rorigin, origins.sname FROM tracks
                            INNER JOIN segments ON tracks.rsegment=segments.rsegment
                            INNER JOIN artists ON artists.rartist=segments.rartist
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN origins ON origins.rorigin=artists.rorigin
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 " #AND origins.rorigin > 0 }
                group_by = "artists.rorigin"
            when VIEW_MTYPES
                sql = %{SELECT #{field}, genres.rgenre, genres.sname FROM tracks
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN genres ON records.rgenre=genres.rgenre
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                        WHERE tracks.iplayed > 0 } #AND records.rgenre > 0 "
                group_by = "records.rgenre"
            when VIEW_LABELS
                sql = %{SELECT #{field}, labels.rlabel, labels.sname FROM tracks
                            INNER JOIN records ON tracks.rrecord=records.rrecord
                            INNER JOIN labels ON records.rlabel=labels.rlabel
                            INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                         WHERE tracks.iplayed > 0 }
                group_by = "records.rlabel"
        end
        sql += @filter unless @filter.empty?
        sql += "GROUP BY #{group_by} "
        sql += "HAVING totplayed > 0 AND records.itrackscount > 1 " if @view_type == VIEW_RECORDS_FULL
        sql += "ORDER BY totplayed DESC LIMIT #{Cfg.max_items+50};"
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
        DBIntf.execute(generate_sql) do |row|
            entry = ChartEntry.new
            entry.played = row[0].to_i
            entry.ref = row[1]
            i += 1
            if entry.played != last_played
                rank = i
                last_played = entry.played
            end
            entry.rank = rank

            # If view is other than tracks or record, the entry is fully loaded in this loop
            unless view_tracks_or_records?
                entry.title = row[2].to_html_bold
                entry.pix   = XIntf::Image::Cache.get_flag(row[3]) if @view_type == VIEW_ARTISTS
                entry.pix   = XIntf::Image::Cache.get_flag(row[1]) if @view_type == VIEW_COUNTRIES
            end

            @entries << entry
        end

        # Done if not tracks or records charts
        return unless view_tracks_or_records?

        # Pix and title loading are in another loop because making db accesses while reading
        # the result set of the query greatly speeds the things down...
        @entries.each do |entry|
            if @view_type == VIEW_TRACKS
                entry.xlink = XIntf::Link.new.set_track_ref(entry.ref)
                entry.pix   = entry.xlink.small_track_cover
                entry.title = entry.xlink.html_track_title_no_track_num(@mc.show_segment_title?)
            else
                entry.xlink = XIntf::Link.new.set_record_ref(entry.ref)
                entry.pix   = entry.xlink.small_record_cover
                entry.title = entry.xlink.html_record_title
            end
        end
    end

    #
    # Dumps the cache array into the tree view model.
    # If is_reload is true, iters are updated otherwise they're added.
    #
    def display_charts(is_reload)
        @entries.each_with_index do |entry, i|
            break if i == Cfg.max_items
            iter = is_reload ? @lsc.get_iter(i.to_s) : @lsc.append
            iter[COL_RANK]  = entry.rank #.to_s
            if @count_type == COUNT_PLAYED
                iter[COL_PLAYED] = entry.played.to_s
            else
                if view_tracks_or_records?
                    iter[COL_PLAYED] = entry.played.to_hr_length
                else
                    iter[COL_PLAYED] = entry.played.to_day_length
                end
            end
            iter[COL_REF]  = entry.ref
            iter[COL_PIX]  = entry.pix
            iter[COL_TEXT] = entry.title
        end
    end

    #
    # Sets the columns titles and visibility and makes a snapshot of the database.
    #
    def load_view(view_type, widget)
        return if widget && !widget.active?

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
        Trace.debug("Charts full load done".red)
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

        if @view_type == VIEW_RECORDS_FULL
            min = DBIntf.get_first_value("SELECT MIN(tracks.iplayed) FROM tracks WHERE tracks.rrecord=#{ref}")
            if @count_type == COUNT_PLAYED
                @entries[pos].played += 1 if @entries[pos].played < min
            else
                @entries[pos].played += @entries[pos].xlink.record.iplaytime if @entries[pos].played < min*@entries[pos].xlink.record.iplaytime
            end
        else
            @entries[pos].played += (@count_type == COUNT_PLAYED ? 1 : track.iplaytime) if update
        end

        @entries.sort! { |ce1, ce2| ce2.played <=> ce1.played }

        rank = pos = 0
        last_played = -1
        @entries.each_with_index do |entry, i|
            if entry.played != last_played
                rank = i+1
                last_played = entry.played
            end
            entry.rank = rank
            pos = i if entry.ref == ref
        end
        display_charts(true) if pos < Cfg.max_items
        Trace.debug("Charts lazy update done".green)
    end

    def show
        load_view(@view_type, nil)
        super
    end
end
