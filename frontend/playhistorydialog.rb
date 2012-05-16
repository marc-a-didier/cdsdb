
class PlayHistoryDialog

    def initialize
        @glade = GTBld::load(UIConsts::PLAY_HISTORY_DIALOG)
        @dlg = @glade[UIConsts::PLAY_HISTORY_DIALOG]

        @tv = @glade[UIConsts::PH_TV]
    end

    def show_ranking(sql, ref)
        n = prev = rank = pos = 0
        DBIntf::connection.execute(sql) { |row|
            n += 1
            rank = n if prev != row[0]
            if row[1] == ref
                pos = rank
                break
            end
            prev = row[0]
        }

        @glade[UIConsts::PH_CHARTS_LBL].text = pos == 0 ? "---" : rank.to_s
    end

    def show_track_history(rtrack)
        srenderer = Gtk::CellRendererText.new()

        ["Entry", "Played", "Host name"].each_with_index { |name, index|
            @tv.append_column(Gtk::TreeViewColumn.new(name, srenderer, :text => index))
        }

        @tv.model = Gtk::ListStore.new(Integer, String, String)
        count = 0
        DBIntf::connection.execute("SELECT * FROM logtracks WHERE rtrack=#{rtrack} ORDER BY idateplayed DESC;") do |row|
            count += 1
            iter = @tv.model.append
            iter[0] = count
            iter[1] = Time.at(row[2]).ctime
            #iter[1] = Time.at(row[2]).to_s
            iter[2] = row[3]
        end

		sql = %Q{SELECT COUNT(logtracks.rlogtrack) AS totplayed, tracks.rtrack FROM tracks
				 INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
				 WHERE tracks.iplayed > 0
				 GROUP BY tracks.rtrack ORDER BY totplayed DESC;}
        show_ranking(sql, rtrack)
    end

    def show_record_history(rrecord)
        srenderer = Gtk::CellRendererText.new()

        ["Entry", "Track", "Title", "Played", "Host name"].each_with_index { |name, index|
            @tv.append_column(Gtk::TreeViewColumn.new(name, srenderer, :text => index))
        }

        @tv.columns[2].resizable = true

        @tv.model = Gtk::ListStore.new(Integer, String, String, String, String)

        count = 0
        DBIntf::connection.execute(
            %Q{SELECT tracks.iorder, tracks.stitle, logtracks.idateplayed, logtracks.shostname
               FROM logtracks, tracks
               WHERE tracks.rtrack=logtracks.rtrack AND tracks.rrecord=#{rrecord}
               ORDER BY logtracks.idateplayed DESC;}) do |row|
            count += 1
            iter = @tv.model.append
            iter[0] = count
            #row.each_with_index { |col, i| iter[i+1] = i == 2 ?  Time.at(row[2].to_i).to_s : col }
            row.each_with_index { |col, i| iter[i+1] = i == 2 ?  Time.at(row[2]).ctime : col.to_s }
        end

        sql = %Q{SELECT COUNT(logtracks.rlogtrack) AS totplayed, records.rrecord FROM tracks
                 INNER JOIN records ON tracks.rrecord=records.rrecord
                 INNER JOIN artists ON artists.rartist=records.rartist
                 INNER JOIN logtracks ON tracks.rtrack=logtracks.rtrack
                 WHERE tracks.iplayed > 0
                 GROUP BY records.rrecord ORDER BY totplayed DESC;}
        show_ranking(sql, rrecord)
    end

    def show_track(rtrack)
        show_track_history(rtrack)
        @dlg.run
        @dlg.destroy
    end

    def show_record(rrecord)
        show_record_history(rrecord)
        @dlg.run
        @dlg.destroy
    end

end
