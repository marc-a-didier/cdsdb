
module Dialogs

    module Audio

        def self.run(file_name)
            GtkUI.load_window(GtkIDs::AUDIO_DIALOG)

            tags = TagLib::File.new(file_name)
            GtkUI[GtkIDs::AUDIO_ENTRY_FILE].text = file_name
            GtkUI[GtkIDs::AUDIO_LBL_DFILESIZE].text = File.size(file_name).to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1\'")+" bytes"
            GtkUI[GtkIDs::AUDIO_LBL_DTITLE].text = tags.title
            GtkUI[GtkIDs::AUDIO_LBL_DARTIST].text = tags.artist
            GtkUI[GtkIDs::AUDIO_LBL_DALBUM].text = tags.album
            GtkUI[GtkIDs::AUDIO_LBL_DTRACK].text = tags.track.to_s
            GtkUI[GtkIDs::AUDIO_LBL_DYEAR].text = tags.year.to_s
            GtkUI[GtkIDs::AUDIO_LBL_DDURATION].text = (tags.length*1000).to_ms_length
            GtkUI[GtkIDs::AUDIO_LBL_DGENRE].text = tags.genre
            GtkUI[GtkIDs::AUDIO_ENTRY_COMMENT].text = tags.comment

            GtkUI[GtkIDs::AUDIO_LBL_DCODEC].text = "???"
            GtkUI[GtkIDs::AUDIO_LBL_DCHANNELS].text = tags.channels.to_s
            GtkUI[GtkIDs::AUDIO_LBL_DSAMPLERATE].text = tags.samplerate.to_s+" Hz"
            GtkUI[GtkIDs::AUDIO_LBL_DBITRATE].text = tags.bitrate.to_s+" Kbps"

            tags.close

            GtkUI[GtkIDs::AUDIO_DIALOG].run
            GtkUI[GtkIDs::AUDIO_DIALOG].destroy
        end
    end


    module Export

        Params = Struct.new(:src_folder, :dest_folder, :remove_genre, :fat_compat)

        def self.run(exp_params)
            GtkUI.load_window(GtkIDs::EXPORT_DEVICE_DIALOG)
            Prefs.restore_window(GtkIDs::EXPORT_DEVICE_DIALOG)
            resp = GtkUI[GtkIDs::EXPORT_DEVICE_DIALOG].run
            if resp == Gtk::Dialog::RESPONSE_OK
                Prefs.save_window_objects(GtkIDs::EXPORT_DEVICE_DIALOG)
                exp_params.src_folder   = GtkUI[GtkIDs::EXP_DLG_FC_SOURCE].current_folder+"/"
                exp_params.dest_folder  = GtkUI[GtkIDs::EXP_DLG_FC_DEST].current_folder+"/"
                exp_params.remove_genre = GtkUI[GtkIDs::EXP_DLG_CB_RMGENRE].active?
                exp_params.fat_compat   = GtkUI[GtkIDs::EXP_DLG_CB_FATCOMPAT].active?
            end
            GtkUI[GtkIDs::EXPORT_DEVICE_DIALOG].destroy
            return resp
        end
    end


    module Preferences

        def self.run
            GtkUI.load_window(GtkIDs::PREFS_DIALOG)
            Prefs.restore_window(GtkIDs::PREFS_DIALOG)
            if GtkUI[GtkIDs::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
                Prefs.save_window_objects(GtkIDs::PREFS_DIALOG)
                Cfg.save
            end
            GtkUI[GtkIDs::PREFS_DIALOG].destroy
        end
    end

    module DateChooser

        include GtkIDs

        def self.set_date(control)
            GtkUI.load_window(DLG_DATE_SELECTOR)
            GtkUI[DATED_CALENDAR].signal_connect(:day_selected_double_click) { GtkUI[DATED_BTN_OK].send(:clicked) }
            if GtkUI[DLG_DATE_SELECTOR].run == Gtk::Dialog::RESPONSE_OK
                dt = GtkUI[DATED_CALENDAR].date
                control.text = dt[0].to_s+"-"+dt[1].to_s+"-"+dt[2].to_s
            end
            GtkUI[DLG_DATE_SELECTOR].destroy
        end

        def self.run
            dates = nil
            GtkUI.load_window(DLG_DATE_CHOOSER)

            GtkUI[DTDLG_BTN_FROMDATE].signal_connect(:clicked) { set_date(GtkUI[DTDLG_ENTRY_FROMDATE]) }
            GtkUI[DTDLG_BTN_TODATE].signal_connect(:clicked)   { set_date(GtkUI[DTDLG_ENTRY_TODATE])   }

            GtkUI[DLG_DATE_CHOOSER].run do |response|
                if response == Gtk::Dialog::RESPONSE_OK
                    dates = [GtkUI[DTDLG_ENTRY_FROMDATE].text.to_date, GtkUI[DTDLG_ENTRY_TODATE].text.to_date]

                    # Switch dates if only until date is filled
                    (dates[0], dates[1] = dates[1], dates[0]) if dates[0] == 0

                    # Do nothing if no dates given or no from date
                    if dates[0] != 0
                        # If no until date, set it to the same day
                        dates[1] = dates[0] if dates[1] == 0
                        # Set until date to next day at 0:00
                        dates[1] += 60*60*24
                    end
                    dates = nil if dates[0] == 0
                end
            end
            GtkUI[DLG_DATE_CHOOSER].destroy
            return dates
        end
    end

    module TrackPLists

        COL_PLIST = 0
        COL_ENTRY = 1
        COL_REF   = 2

        def self.run(mc, rtrack)
            GtkUI.load_window(GtkIDs::TRK_PLISTS_DIALOG)

            tv = GtkUI[GtkIDs::TRK_PLISTS_TV]

            GtkUI[GtkIDs::TRK_PLISTS_BTN_SHOW].signal_connect(:clicked) do
                if tv.selection.selected
                    GtkUI[GtkIDs::MM_WIN_PLAYLISTS].send(:activate) unless mc.plists.window.visible?
                    mc.plists.position_browser(tv.selection.selected[COL_REF])
                end
            end

            srenderer = Gtk::CellRendererText.new()

            # Columns: Play list, Order, PL track ref (hidden)
            tv.model = Gtk::ListStore.new(String, Integer, Integer)

            tv.append_column(Gtk::TreeViewColumn.new("Play list", srenderer, :text => COL_PLIST))
            tv.append_column(Gtk::TreeViewColumn.new("Entry", srenderer, :text => COL_ENTRY))

            sql = %{SELECT plists.sname, pltracks.iorder, pltracks.rpltrack, plists.rplist FROM pltracks
                      INNER JOIN plists ON plists.rplist = pltracks.rplist
                    WHERE pltracks.rtrack=#{rtrack};}
            DBIntf.execute(sql) do |row|
                iter = tv.model.append
                row[1] = DBIntf.get_first_value(%{SELECT COUNT(rpltrack)+1 FROM pltracks
                                                  WHERE rplist=#{row[3]} AND iorder<#{row[1]};})
                row.each_with_index { |val, i| iter[i] = val if i < 3 }
            end

            GtkUI[GtkIDs::TRK_PLISTS_DIALOG].run
            GtkUI[GtkIDs::TRK_PLISTS_DIALOG].destroy
        end
    end

    module PlayHistory

        def self.show_ranking(sql, ref)
            n = prev = rank = pos = 0
            DBIntf.execute(sql) do |row|
                n += 1
                rank = n if prev != row[0]
                if row[1] == ref
                    pos = rank
                    break
                end
                prev = row[0]
            end

            GtkUI[GtkIDs::PH_CHARTS_LBL].text = pos == 0 ? "---" : rank.to_s
        end

        def self.show_track_history(rtrack)
            tv = GtkUI[GtkIDs::PH_TV]

            srenderer = Gtk::CellRendererText.new()

            ["Entry", "Played", "Host name"].each_with_index { |name, index|
                tv.append_column(Gtk::TreeViewColumn.new(name, srenderer, :text => index))
            }

            tv.model = Gtk::ListStore.new(Integer, String, String)
            count = 0
            DBIntf.execute(
                %{SELECT logtracks.idateplayed, hostnames.sname FROM logtracks
                    INNER JOIN hostnames ON logtracks.rhostname=hostnames.rhostname
                  WHERE rtrack=#{rtrack} ORDER BY idateplayed DESC;}) do |row|
                count += 1
                iter = tv.model.append
                iter[0] = count
                iter[1] = Time.at(row[0]).ctime
                iter[2] = row[1]
            end

            sql = %{SELECT COUNT(logtracks.rtrack) AS totplayed, tracks.rtrack FROM tracks
                      INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                    WHERE tracks.iplayed > 0
                    GROUP BY tracks.rtrack ORDER BY totplayed DESC;}
            show_ranking(sql, rtrack)
        end

        def self.show_record_history(rrecord)
            tv = GtkUI[GtkIDs::PH_TV]

            srenderer = Gtk::CellRendererText.new()

            ["Entry", "Track", "Title", "Played", "Host name"].each_with_index { |name, index|
                tv.append_column(Gtk::TreeViewColumn.new(name, srenderer, :text => index))
            }

            tv.columns[2].resizable = true

            tv.model = Gtk::ListStore.new(Integer, String, String, String, String)

            count = 0
            DBIntf.execute(
                %{SELECT tracks.iorder, tracks.stitle, logtracks.idateplayed, hostnames.sname FROM tracks
                    INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                    INNER JOIN hostnames ON logtracks.rhostname=hostnames.rhostname
                  WHERE tracks.rrecord=#{rrecord}
                  ORDER BY logtracks.idateplayed DESC;}) do |row|
                count += 1
                iter = tv.model.append
                iter[0] = count
                row.each_with_index { |col, i| iter[i+1] = i == 2 ?  Time.at(row[2]).ctime : col.to_s }
            end

            sql = %{SELECT COUNT(logtracks.rtrack) AS totplayed, records.rrecord FROM tracks
                      INNER JOIN records ON tracks.rrecord=records.rrecord
                      INNER JOIN artists ON artists.rartist=records.rartist
                      INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                    WHERE tracks.iplayed > 0
                    GROUP BY records.rrecord ORDER BY totplayed DESC;}
            show_ranking(sql, rrecord)
        end

        def self.show_track(rtrack)
            GtkUI.load_window(GtkIDs::PLAY_HISTORY_DIALOG)
            self.show_track_history(rtrack)
            GtkUI[GtkIDs::PLAY_HISTORY_DIALOG].run
            GtkUI[GtkIDs::PLAY_HISTORY_DIALOG].destroy
        end

        def self.show_record(rrecord)
            GtkUI.load_window(GtkIDs::PLAY_HISTORY_DIALOG)
            self.show_record_history(rrecord)
            GtkUI[GtkIDs::PLAY_HISTORY_DIALOG].run
            GtkUI[GtkIDs::PLAY_HISTORY_DIALOG].destroy
        end

    end
end
