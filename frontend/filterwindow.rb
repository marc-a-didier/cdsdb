
class FilterWindow < TopWindow

    include GtkIDs

    # Struct that keeps the infos needed to compute a weight or to sort on given criteria
    #     weight:  Global computed weight
    #     rtrack:  DB ref
    #     played:  Played weight in % in regard of the most played track of the selection
    #     rating:  Rating weight in %
    #     title:   Not used, only for debug.
    TrackData = Struct.new(:weight, :played, :rating, :rtrack, :title)

    DEST_PLIST  = 0
    DEST_PQUEUE = 1

    TITLES = { "genres" => "Genre", "origins" => "Country", "medias" => "Medium" } # "labels" => "Label"
    COND_FIELDS = ["records.rgenre", "artists.rorigin", "records.rmedia"] # Fields to sort on
    EXP_FILEDS = [FLT_EXP_GENRES, FLT_EXP_ORIGINS, FLT_EXP_MEDIAS]

    def initialize(mc)
        super(mc, FILTER_WINDOW)

        GtkUI[FLT_BTN_APPLY].signal_connect(:clicked) { @mc.filter_receiver.set_filter(generate_filter, @must_join_logtracks) }
        GtkUI[FLT_BTN_CLEAR].signal_connect(:clicked) { @mc.filter_receiver.set_filter("", false) }
        GtkUI[FLT_BTN_SAVE].signal_connect(:clicked)  { save_filter }
        GtkUI[FLT_BTN_PLGEN].signal_connect(:clicked) { generate_play_list(DEST_PLIST) }
        GtkUI[FLT_BTN_PQGEN].signal_connect(:clicked) { generate_play_list(DEST_PQUEUE) }

        GtkUI[FLT_POPITM_NEW].signal_connect(:activate)    { new_filter }
        GtkUI[FLT_POPITM_DELETE].signal_connect(:activate) { delete_filter }

        GtkUI[FLT_BTN_FROMDATE].signal_connect(:clicked) { set_date(GtkUI[FLT_ENTRY_FROMDATE]) }
        GtkUI[FLT_BTN_TODATE].signal_connect(:clicked)   { set_date(GtkUI[FLT_ENTRY_TODATE]) }

        @tv_tags = GtkUI[FTV_TAGS]
        GtkUtils.setup_tracks_tags_tv(@tv_tags)
        @tv_tags.columns[0].clickable = true
        @tv_tags.columns[0].signal_connect(:clicked) { @tv_tags.model.each { |model, path, iter| iter[0] = !iter[0] } }

        [FLT_CMB_MINRATING, FLT_CMB_MAXRATING].each { |cmb| GtkUI[cmb].remove_text(0) }
        Qualifiers::RATINGS.each { |rating| GtkUI[FLT_CMB_MINRATING].append_text(rating) }
        Qualifiers::RATINGS.each { |rating| GtkUI[FLT_CMB_MAXRATING].append_text(rating) }

        @tvs = []
        TITLES.each_key { |key| @tvs << setup_tv(key) }

        edrenderer = Gtk::CellRendererText.new()
        edrenderer.editable = true
        edrenderer.signal_connect(:edited) { |widget, path, new_text| ftv_name_edited(widget, path, new_text) }

        @ftv = GtkUI["flt_tv_dbase"]
        @ftv.model = Gtk::ListStore.new(Integer, String, String)

        @ftv.append_column(Gtk::TreeViewColumn.new("Ref.", Gtk::CellRendererText.new(), :text => 0))
        @ftv.append_column(Gtk::TreeViewColumn.new("Filter name", edrenderer, :text => 1))
        @ftv.append_column(Gtk::TreeViewColumn.new("YAML", Gtk::CellRendererText.new(), :text => 2))
#         @ftv.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, 1) }
        @ftv.model.set_sort_column_id(1, Gtk::SORT_ASCENDING)
        @ftv.columns[1].sort_indicator = Gtk::SORT_ASCENDING
        @ftv.columns[1].clickable = true
        @ftv.columns[2].visible = false

#         set_ref_column_visibility(GtkUI[MM_VIEW_DBREFS].active?)
        @ftv.selection.signal_connect(:changed)  { |widget| on_filter_changed(widget) }
        @ftv.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, FLT_POP_ACTIONS) }
        load_ftv

        @must_join_logtracks = false
    end

    def setup_tv(table_name)
        tv = GtkUI["ftv_"+table_name]
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
        DBIntf.execute("SELECT * FROM #{table_name};") do |row|
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

    def show_popup(widget, event, menu_name)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            # No popup if no selection in the tree view
            GtkUI[menu_name].popup(nil, nil, event.button, event.time) if @ftv.selection.selected
        end
    end

    def load_ftv
        @ftv.model.clear
        DBIntf.execute("SELECT * FROM filters") { |row|
            iter = @ftv.model.append
            row.each_index { |column| iter[column] = column == 2 ? row[column].gsub(/\\n/, "\n") : row[column] }
        }
    end

    def set_ref_column_visibility(is_visible)
        @ftv.columns[0].visible = is_visible
    end

    def on_filter_changed(widget)
        # @ftv.selection.selected may be nil when a new filter is created
        PREFS.content_from_yaml(@ftv.selection.selected[2]) if @ftv.selection.selected
    end

    def new_filter
        max_id = 0
        @ftv.model.each { |model, path, iter| max_id = iter[0] if iter[0] > max_id }
        DBUtils.client_sql("INSERT INTO filters VALUES (#{max_id+1}, 'New filter', '---\nfilter: {}\n')")
        load_ftv
    end

    def delete_filter
        DBUtils.client_sql("DELETE FROM filters WHERE rfilter=#{@ftv.selection.selected[0]}")
        load_ftv
    end

    def save_filter
        yml_data = PREFS.yaml_from_content(GtkUI[FLT_VBOX_EXPANDERS]).to_sql
        DBUtils.client_sql("UPDATE filters SET sxmldata=#{yml_data} WHERE rfilter=#{@ftv.selection.selected[0]}")
        @ftv.selection.selected[2] = yml_data
    end

    def ftv_name_edited(widget, path, new_text)
        DBUtils.client_sql("UPDATE filters SET sname=#{new_text.to_sql} WHERE rfilter=#{@ftv.selection.selected[0]}")
        @ftv.selection.selected[1] = new_text
    end

    def set_date(control)
        GtkUI.load_window(DLG_DATE_SELECTOR)
        GtkUI[DATED_CALENDAR].signal_connect(:day_selected_double_click) { GtkUI[DATED_BTN_OK].send(:clicked) }
        if GtkUI[DLG_DATE_SELECTOR].run == Gtk::Dialog::RESPONSE_OK
            dt = GtkUI[DATED_CALENDAR].date
            control.text = dt[0].to_s+"-"+dt[1].to_s+"-"+dt[2].to_s
        end
        GtkUI[DLG_DATE_SELECTOR].destroy
    end

    def generate_filter()
        is_for_charts = @mc.filter_receiver == @mc.charts
        @must_join_logtracks = GtkUI[FLT_EXP_PLAYDATES].expanded?

        wc = ""
        if GtkUI[FLT_EXP_PCOUNT].expanded?
            min = GtkUI[FLT_SPIN_MINP].value.round
            max = GtkUI[FLT_SPIN_MAXP].value.round
            wc += " AND tracks.iplayed >= #{min}"
            wc += " AND tracks.iplayed <= #{max}" unless min > max
        end
        if GtkUI[FLT_EXP_RATING].expanded?
            wc += " AND tracks.irating >= #{GtkUI[FLT_CMB_MINRATING].active} AND tracks.irating <= #{GtkUI[FLT_CMB_MAXRATING].active}"
        end
        if GtkUI[FLT_EXP_PLAYTIME].expanded?
            len = GtkUI[FLT_SPIN_MINPTIMEM].value.round*60*1000+GtkUI[FLT_SPIN_MINPTIMES].value.round*1000
            wc += " AND tracks.iplaytime >= #{len}" if len > 0
            len = GtkUI[FLT_SPIN_MAXPTIMEM].value.round*60*1000+GtkUI[FLT_SPIN_MAXPTIMES].value.round*1000
            wc += " AND tracks.iplaytime <= #{len}" if len > 0
        end
        if GtkUI[FLT_EXP_PLAYDATES].expanded?
            from_date = GtkUI[FLT_ENTRY_FROMDATE].text.to_date
            to_date   = GtkUI[FLT_ENTRY_TODATE].text.to_date
#            to_date, from_date = from_date, to_date if to_date < from_date

            wc += " AND (SELECT idateplayed FROM logtracks WHERE logtracks.rtrack=tracks.rtrack" unless is_for_charts
            wc += " AND logtracks.idateplayed >= #{from_date}" if from_date > 0
            wc += " AND logtracks.idateplayed <= #{to_date}" if to_date > 0
            wc += ")" unless is_for_charts
        end


        # Where clause on selected tags if any
        if GtkUI[FLT_EXP_TAGS].expanded?
            mask = GtkUtils.get_tags_mask(@tv_tags)
            unless mask == 0
                wc += GtkUI[FLT_CB_MATCHALL].active? ? " AND ((tracks.itags & #{mask}) = #{mask})" :
                                                           " AND ((tracks.itags & #{mask}) <> 0)"
            end
        end

        @tvs.each_with_index { |tv, i| wc += add_tv_clause(tv.model, COND_FIELDS[i]) if GtkUI[EXP_FILEDS[i]].expanded? }

        wc += " " unless wc.empty?
# puts wc
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
    def generate_play_list(destination)
        wc = generate_filter

        if wc.empty?
            GtkUtils.how_message("Can't generate a play list from the current criteria", Gtk::MessageDialog::ERROR)
            return
        end

        # This option is only available for play list/queue generation
        # so its not coded in the generate_filter method
        wc += " ORDER BY tracks.ilastplayed" if GtkUI[FLT_CMB_SELECTBY].active == 3 # Oldest played tracks

        wc = " WHERE "+wc[5..-1]
        sql = "SELECT tracks.rtrack FROM tracks " \
              "INNER JOIN records ON tracks.rrecord=records.rrecord "+wc+";"

        f = File.new(CFG.rsrc_dir+"genpl.txt", "w")
        f.puts("SQL: #{sql}\n\n")

        max_played = 0
        tracks = []
        dblink = AudioLink.new
        DBIntf.execute(sql) do |row|
            # Skip tracks which aren't ripped
            dblink.reset.set_track_ref(row[0])
            if GtkUI[FLT_CHK_MUSICFILE].active?
                next if dblink.setup_audio_file.status == Audio::Status::NOT_FOUND
            end

            max_played = dblink.track.iplayed if dblink.track.iplayed > max_played

            tracks << TrackData.new(0.0, dblink.track.iplayed.to_f, dblink.track.irating.to_f/6.0*100.0, row[0], dblink.track.stitle)
            f << row[0] << " - " << dblink.track.iplayed << " - " << dblink.track.irating << " - " << dblink.track.stitle << "\n"
        end
        f.puts

        # Filter was too restrictive, no match, exit silently
        if tracks.size == 0
            f.puts("No tracks found to match the filter.")
            f.close
            return
        end

        #
        max_tracks = GtkUI[FLT_SPIN_PLENTRIES].value.round

        # Store play count and rating weight for effiency purpose
        pcweight = GtkUI[FLT_SPIN_PCWEIGHT].value
        rtweight = GtkUI[FLT_SPIN_RATINGWEIGHT].value

        # The array is ready. If random selection, shuffle it else compute and sort by weight
        if GtkUI[FLT_CMB_SELECTBY].active == 0 # Random selection
            rvalues = Utils::rnd_from_file(tracks.size, max_tracks, f)
            tracks = Array.new(rvalues.size).fill { |i| tracks[rvalues[i]] }.uniq
        elsif GtkUI[FLT_CMB_SELECTBY].active != 3 # Do nothing if oldest played first
            tracks.each { |track|
                track.played = track.played/max_played*100.0 if max_played > 0
                track.weight = track.played*pcweight+track.rating*rtweight
                f << track.rtrack << " - pcp: " << track.played << " - rtp: " << track.rating \
                  << " - Weight: " << track.weight << " for " << track.title << "\n"
            }

            tracks.sort! { |t1, t2| t2.weight <=> t1.weight } # reverse sort, most weighted first

            # Manage the starting offset in results if set
            start_offset = 0
            if GtkUI[FLT_HSCL_ADJSELSTART].value > 0.0
                start_offset = tracks.size*GtkUI[FLT_HSCL_ADJSELSTART].value.round/100
                if start_offset+max_tracks > tracks.size
                    start_offset = tracks.size-max_tracks
                    start_offset = 0 if start_offset < 0
                end

                f << "\nStart offset set, starting from offset #{start_offset} of #{tracks.size} tracks\n\n"
                # Remove all elements before start_offset
                tracks.shift(start_offset)
            end

            if GtkUI[FLT_CMB_SELECTBY].active == 2 # Randomize hits with same weight
                # Search for the number of entries with same weight. While we don't have
                # enough tracks, shuffle the first result and append it to the selected tracks
                # array then get all tracks of the next weight and repeat the operation
                # until we have enough tracks. It ensures that the most weighted tracks
                # are first in the list but shuffled.
                stracks = []
                ttracks = []
                count = 0
                curr_weight = tracks[0].weight
                tracks.each { |track|
                    if curr_weight != track.weight
                        ttracks.shuffle!
                        stracks += ttracks
                        ttracks.clear
                        break if count >= max_tracks
                        curr_weight = track.weight
                    end
                    count += 1
                    ttracks << track
                }

                f << "\n" << stracks.size << " tracks selected until weight " << curr_weight << "\n"
                stracks.each { |track| f << track.weight << " " << track.title << "\n" }
                tracks = stracks
            end
        end

        tracks.slice!(max_tracks, tracks.size)

        f.puts; f.puts

        links = []
        if destination == DEST_PLIST
            rplist = DBUtils::get_last_id("plist")+1
            DBIntf.execute("INSERT INTO plists VALUES (#{rplist}, 'Generated', 1, #{Time.now.to_i}, #{Time.now.to_i});")
            rpltrack = DBUtils::get_last_id("pltrack")+1
        end

        tracks.each_with_index { |track, i|
            f << "i="<< i << "  Weight: " << track.weight << " for " << track.title << "\n"
            if destination == DEST_PLIST
                DBIntf.execute("INSERT INTO pltracks VALUES (#{rpltrack+i}, #{rplist}, #{track.rtrack}, #{(i+1)*1024});")
            else
                links << UILink.new.set_track_ref(track.rtrack)
            end
        }
        f.close

        destination == DEST_PLIST ? @mc.reload_plists : @mc.pqueue.enqueue(links)
    end

end
