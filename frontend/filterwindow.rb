
class FilterWindow < TopWindow

    #
    # TODO: add a save/load filter!!!
    #

    include UIConsts

    TRACK_WEIGHT    = 0 # Global computed weight
    TRACK_RTRACK    = 1 # DB ref
    TRACK_PLAYED    = 2 # Played weight in % in regard of the most played track of the selection
    TRACK_RATING    = 3 # Rating weight in %
    TRACK_TITLE     = 4 # Not used, only for debug. To remove asap
    #TRACK_SELECTION = 5

    TITLES = { "genres" => "Genre", "origins" => "Country", "medias" => "Medium" } # "labels" => "Label"
    COND_FIELDS = ["records.rgenre", "artists.rorigin", "records.rmedia"] # Fields to sort on
    EXP_FILEDS = [FLT_EXP_GENRES, FLT_EXP_ORIGINS, FLT_EXP_MEDIAS]

    def initialize(mc)
        super(mc, FILTER_WINDOW)

        @mc.glade[FLT_BTN_APPLY].signal_connect(:clicked) { @mc.filter_receiver.set_filter(generate_filter, @must_join_logtracks) }
#         @mc.glade[FLT_BTN_APPLY].signal_connect(:clicked) do
# 			wins = Gdk::Window::toplevels
# 			wins.each { |win| puts win.id }
# 		end
        @mc.glade[FLT_BTN_CLEAR].signal_connect(:clicked)    { @mc.filter_receiver.set_filter("", false) }
        @mc.glade[FLT_BTN_PLGEN].signal_connect(:clicked)    { generate_play_list }

        @mc.glade[FLT_BTN_FROMDATE].signal_connect(:clicked) { set_date(@mc.glade[FLT_ENTRY_FROMDATE]) }
        @mc.glade[FLT_BTN_TODATE].signal_connect(:clicked)   { set_date(@mc.glade[FLT_ENTRY_TODATE]) }

        @tv_tags = @mc.glade[FTV_TAGS]
        UIUtils::setup_tracks_tags_tv(@tv_tags)
        @tv_tags.columns[0].clickable = true
        @tv_tags.columns[0].signal_connect(:clicked) { @tv_tags.model.each { |model, path, iter| iter[0] = !iter[0] } }

		[FLT_CMB_MINRATING, FLT_CMB_MAXRATING].each { |cmb| @mc.glade[cmb].remove_text(0) }
		RATINGS.each { |rating| @mc.glade[FLT_CMB_MINRATING].append_text(rating) }
		RATINGS.each { |rating| @mc.glade[FLT_CMB_MAXRATING].append_text(rating) }

        @tvs = []
		TITLES.each_key { |key| @tvs << setup_tv(key) }
        #["genres", "origins", "medias"].each { |table| @tvs << setup_tv(table) }

        @must_join_logtracks = false
    end

    def setup_tv(table_name)
        tv = @mc.glade["ftv_"+table_name]
        ls = Gtk::ListStore.new(TrueClass, String, Integer)
        tv.model = ls

        grenderer = Gtk::CellRendererToggle.new
        grenderer.activatable = true
        grenderer.signal_connect(:toggled) do |w, path|
            iter = tv.model.get_iter(path)
            iter[0] = !iter[0] if (iter)
        end
        srenderer = Gtk::CellRendererText.new()

        tv.append_column(Gtk::TreeViewColumn.new("Include", grenderer, :active => 0))
        tv.append_column(Gtk::TreeViewColumn.new(TITLES[table_name], srenderer, :text => 1))
        DBIntf::connection.execute("SELECT * FROM #{table_name};") do |row|
            iter = tv.model.append
            iter[0] = false
            iter[1] = row[1]
            iter[2] = row[0].to_i
        end
        tv.columns[0].clickable = true
        tv.columns[0].signal_connect(:clicked) { tv.model.each { |model, path, iter| iter[0] = !iter[0] } }

        tv.model.set_sort_column_id(1, Gtk::SORT_ASCENDING)

        return tv
    end

    def set_date(control)
        dlg_glade = GTBld.load(DLG_DATE_SELECTOR)
        dlg_glade[DATED_CALENDAR].signal_connect(:day_selected_double_click) { dlg_glade[DATED_BTN_OK].send(:clicked) }
        if dlg_glade[DLG_DATE_SELECTOR].run == Gtk::Dialog::RESPONSE_OK
            dt = dlg_glade[DATED_CALENDAR].date
            control.text = dt[0].to_s+"-"+dt[1].to_s+"-"+dt[2].to_s
        end
        dlg_glade[DLG_DATE_SELECTOR].destroy
    end

    def generate_filter(is_for_charts = false)
        @must_join_logtracks = @mc.glade[FLT_EXP_PLAYDATES].expanded?

        wc = ""
        if @mc.glade[FLT_EXP_PCOUNT].expanded?
            min = @mc.glade[FLT_SPIN_MINP].value.round
            max = @mc.glade[FLT_SPIN_MAXP].value.round
            wc += " AND tracks.iplayed >= #{min}"
            wc += " AND tracks.iplayed <= #{max}" unless min > max
        end
        if @mc.glade[FLT_EXP_RATING].expanded?
            wc += " AND tracks.irating >= #{@mc.glade[FLT_CMB_MINRATING].active} AND tracks.irating <= #{@mc.glade[FLT_CMB_MAXRATING].active}"
        end
        if @mc.glade[FLT_EXP_PLAYTIME].expanded?
            len = @mc.glade[FLT_SPIN_MINPTIMEM].value.round*60*1000+@mc.glade[FLT_SPIN_MINPTIMES].value.round*1000
            wc += " AND tracks.iplaytime >= #{len}"
            len = @mc.glade[FLT_SPIN_MAXPTIMEM].value.round*60*1000+@mc.glade[FLT_SPIN_MAXPTIMES].value.round*1000
            wc += " AND tracks.iplaytime <= #{len}"
        end
        if @mc.glade[FLT_EXP_PLAYDATES].expanded?
            from_date = @mc.glade[FLT_ENTRY_FROMDATE].text.to_date
            to_date   = @mc.glade[FLT_ENTRY_TODATE].text.to_date
#            to_date, from_date = from_date, to_date if to_date < from_date

            wc += " AND (SELECT idateplayed FROM logtracks WHERE logtracks.rtrack=tracks.rtrack" unless is_for_charts
            wc += " AND logtracks.idateplayed >= #{from_date}" if from_date > 0
            wc += " AND logtracks.idateplayed <= #{to_date}" if to_date > 0
            wc += ")" unless is_for_charts
        end


        # Where clause on selected tags if any
        if @mc.glade[FLT_EXP_TAGS].expanded?
            mask = UIUtils::get_tags_mask(@tv_tags)
            unless mask == 0
                wc += @mc.glade[FLT_CB_MATCHALL].active? ? " AND ((tracks.itags & #{mask}) = #{mask})" :
                                                           " AND ((tracks.itags & #{mask}) <> 0)"
            end
        end

        @tvs.each_with_index { |tv, i| wc += add_tv_clause(tv.model, COND_FIELDS[i]) if @mc.glade[EXP_FILEDS[i]].expanded? }

        wc += " " unless wc.empty?
puts wc
        return wc
    end

    def add_tv_clause(ls, cond_field)
        wc = ""
        total = selected = 0
        ls.each { |model, path, iter| total += 1; selected += 1 if iter[0] == true }
        if selected > 0 && selected != total
            cond = " IN ("
            if selected <= total/2
                ls.each { |model, path, iter| cond += iter[2].to_s+"," if iter[0] == true }
            else
                cond = " NOT"+cond
                ls.each { |model, path, iter| cond += iter[2].to_s+"," if iter[0] == false }
            end
            cond[-1] = ")"
            wc = " AND ("+cond_field+cond+")"
        end
        return wc
    end

    #
    # Generate play list from filter
    #
    def generate_play_list
        wc = generate_filter
        wc = " WHERE "+wc[5..-1] unless wc.empty?
        sql = "SELECT tracks.rtrack, tracks.iplayed, tracks.irating, tracks.stitle, tracks.iplaytime, records.rgenre FROM tracks " \
              "INNER JOIN records ON tracks.rrecord=records.rrecord "+wc+";"
puts sql
        f = File.new(Cfg::instance.rsrc_dir+"genpl.txt", "w")

        max_played = 0
        tracks = []
        track_infos = TrackInfos.new
        DBIntf.connection.execute(sql) do |row|
            # Skip tracks which aren't ripped
            next if Utils::audio_file_exists(track_infos.get_track_infos(row[0])).status == Utils::FILE_NOT_FOUND

            max_played = row[1] if row[1] > max_played
            tracks << [0.0, row[0], row[1].to_f, row[2].to_f/6.0*100.0, row[3]]
            f << row[0] << " - " << row[1] << " - " << row[2] << " - " << row[3] << "\n"
        end
        f.puts

        # Filter was too restrictive, no match, exit silently
        return if tracks.size == 0

        # Store play count and rating weight for effiency purpose
        pcweight = @mc.glade[UIConsts::FLT_SPIN_PCWEIGHT].value
        rtweight = @mc.glade[UIConsts::FLT_SPIN_RATINGWEIGHT].value

        # The array is ready. If random selection, shuffle it else compute and sort by weight
        if @mc.glade[UIConsts::FLT_CMB_SELECTBY].active == 0 # Random selection
            tracks.shuffle!
        else
            tracks.each { |track|
                track[TRACK_PLAYED]  = track[TRACK_PLAYED]/max_played*100.0 if max_played > 0
                track[TRACK_WEIGHT] += track[TRACK_PLAYED]*pcweight if pcweight > 0.0
                track[TRACK_WEIGHT] += track[TRACK_RATING]*rtweight if rtweight > 0.0
                f << track[TRACK_RTRACK] << " - pcp: " << track[TRACK_PLAYED] << " - rtp: " << track[TRACK_RATING] \
                  << " - Weight: " << track[TRACK_WEIGHT] << " for " << track[TRACK_TITLE] << "\n"
            }
            tracks.sort! { |t1, t2| t2[TRACK_WEIGHT] <=> t1[TRACK_WEIGHT] } # reverse sort, most weighted first
        end

        tracks.slice!(@mc.glade[UIConsts::FLT_SPIN_PLENTRIES].value.round, tracks.size)

        f.puts; f.puts

        rplist = DBUtils::get_last_id("plist")+1
        DBIntf::connection.execute("INSERT INTO plists VALUES (#{rplist}, 'Generated', 1, \
                                    #{Time.now.to_i}, #{Time.now.to_i});")

        rpltrack = DBUtils::get_last_id("pltrack")+1
        tracks.each_with_index { |track, i|
            f << "i="<< i << "  Weight: " << track[TRACK_WEIGHT] << " for " << track[TRACK_TITLE] << "\n"
            DBIntf::connection.execute("INSERT INTO pltracks VALUES (#{rpltrack+i}, #{rplist}, #{track[TRACK_RTRACK]}, #{i+1});")
        }
        f.close

        @mc.reload_plists
    end

end
