
#
# Generate statistics in a text file based on various criteria
#

class Stats

    #
    # Needs:
    #   1. nombre total de disques dans la base
    #   2. nombre de disques par type (cd, cdr, audio file)
    #   3. nombre total de disques rippes (excluant les audio file)
    #   4. nombre de disques par type de muse
    #   5. nombre de disques rippes par type de muse
    # nombre signifie nombre ET duree
    #

    GENRE_REF           = 0
    GENRE_NAME          = 1
    GENRE_TOT_TIME      = 2
    GENRE_TOT_TRACKS    = 3
    GENRE_PLAYED_TIME   = 4
    GENRE_PLAYED_TRACKS = 5
    GENRE_TOT_RECS      = 6
    GENRE_TOT_RECTIME   = 7
    GENRE_RIPPED        = 8
    GENRE_RIPTIME       = 9

    DBTOTS_ARTISTS = 0
    DBTOTS_RECORDS = 1
    DBTOTS_SEGS    = 2
    DBTOTS_TRACKS  = 3
    DBTOTS_PTIME   = 4

    TV_ITEMS = {"Played tracks" => [false, :played_tracks_stats],
                "Rated and tagged tracks" => [false, :rating_tags_stats],

                "Records by artists" => [false,  :records_by_artists],
                "Records by genres" => [true, :records_by_genre],

                "Last 1000 played" => [false, :gen_play_history],

                "Charts by genre" => [false, :top_genres],
                "Charts by genre & artists" => [false, :charts_by_artists],
                "Charts by genre & records" => [false, :charts_by_records],
                "Charts by genre & tracks" => [false, :charts_by_tracks],

                "List of rated tracks" => [false, :top_rated_tracks] }

    class ColorAlternator

        attr_reader :counter

        def initialize
            reset
        end

        def reset
            @counter = 0
        end

        def get_color
            @counter += 1
            @counter.even? ? '<tr>' : '<tr class="alt">'
        end
    end

    def initialize(mc)
        @mc = mc
        @altr = ColorAlternator.new
    end

    def new_table(title, headers = [])
        @f << "<h1>" << title << "</h1><br />"
        @f << '<table id="mytbl">'
        @altr.reset
        headers.each { |header| @f << "<th>" << header << "</th>" }
    end

    def new_row(cols)
        @f << @altr.get_color
        cols.each { |col_title| @f << "<td>" << col_title.to_s << "</td>" }
        @f << "</tr>"
    end

    def end_table(html_epilogue = "")
        @f << "</table><hr /><br /><br />"+html_epilogue
    end

    def get_count(stbl)
        return DBIntf::connection.get_first_value("SELECT COUNT(r#{stbl}) FROM #{stbl}s;")
    end

    def init_globals(fname, title)
        @f = File.new(fname, "w")
        @f << "<!DOCTYPE html><head>"
        @f << '<meta charset="UTF-8">'
        @f << "<title>#{title}</title>"
        @f << '<style type="text/css">'
        @f << 'h1 {font-size: 18px; font-family: "sans";}'
        @f << 'h2 {font-size: 16px; font-family: "sans";}'
        @f << 'p {font-size: 10px; font-family: "sans";}'
#         @f << 'td {font-size: 10px; font-family: "sans";}'
        @f << %{
                #mytbl
                {
                    font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
                    border-collapse:collapse;
                }
                #mytbl td, #mytbl th
                {
                    font-size:1em;
                    border:1px solid #98bf21;
                    padding:3px 7px 2px 7px;
                }
                #mytbl th
                {
                    font-size:1.1em;
                    text-align:left;
                    padding-top:5px;
                    padding-bottom:4px;
                    background-color:#A7C942;
                    color:#ffffff;
                }
                #mytbl tr.alt td
                {
                    color:#000000;
                    background-color:#B5DDF7;
                }
                }
#                     background-color:#EAF2D3;
        @f << '</style></head><body>'

        @genres = []
        @db_tots = []
        @media = Hash.new

        @db_tots << get_count('artist') << get_count('record') << get_count('segment') << get_count('track')
        @db_tots << DBIntf::connection.get_first_value("SELECT SUM(iplaytime) FROM records").to_i

        @genres << [0, "", 0, 0, 0, 0, 0, 0, 0, 0]
        DBIntf::connection.execute("SELECT * FROM genres WHERE rgenre<>0 ORDER BY sname;") { |row| @genres << [row[0], row[1], 0, 0, 0, 0, 0, 0, 0, 0] }
        @genres.each { |genre| init_table(genre) }
        @genres.delete_if { |genre| genre[GENRE_TOT_TRACKS] == 0 } # Remove genres with no tracks
    end

    def db_general_infos
        new_table("General infos")
        new_row(["Total number of artists", @db_tots[DBTOTS_ARTISTS]])
        new_row(["Total number of records", "#{@db_tots[DBTOTS_RECORDS]} - Play time: #{@db_tots[DBTOTS_PTIME].to_day_length}"])
        new_row(["Total number of segments", @db_tots[DBTOTS_SEGS]])
        new_row(["Total number of tracks", @db_tots[DBTOTS_TRACKS]])
        end_table

        new_table("Records by media type", ["Medium", "Records", "Play time"])
        DBIntf::connection.execute("SELECT * FROM medias;") do |mediatype|
            DBIntf::connection.execute("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia=#{mediatype[0]};") do |row|
                #Gtk.main_iteration while Gtk.events_pending?
                @media[mediatype[1]] = [row[0], row[1]]
                new_row([mediatype[1], row[0], row[1].to_i.to_day_length])
            end
        end
        end_table
    end

    def init_table(genre)
        if genre[GENRE_REF] == 0
            row = DBIntf::connection.get_first_row("SELECT COUNT(rtrack), SUM(iplaytime) FROM tracks;")
            genre[GENRE_TOT_TRACKS] = row[0].to_i
            genre[GENRE_TOT_TIME] = row[1].to_i
            row = DBIntf::connection.get_first_row("SELECT SUM(iplayed), SUM(iplaytime) FROM tracks WHERE iplayed > 0;")
            genre[GENRE_PLAYED_TRACKS] = row[0].to_i
            genre[GENRE_PLAYED_TIME] = row[1].to_i
            row = DBIntf::connection.get_first_row("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia <> #{DBIntf::MEDIA_AUDIO_FILE}")
            genre[GENRE_TOT_RECS] = row[0].to_i
            genre[GENRE_TOT_RECTIME] = row[1].to_i
        else
            sql = "SELECT COUNT(tracks.rtrack), SUM(tracks.iplaytime) FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE records.rgenre=#{genre[GENRE_REF]};"
            row = DBIntf::connection.get_first_row(sql)
            genre[GENRE_TOT_TRACKS] = row[0].to_i
            genre[GENRE_TOT_TIME] = row[1].to_i
            sql = "SELECT COUNT(tracks.rtrack), SUM(tracks.iplaytime) FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]};"
            row = DBIntf::connection.get_first_row(sql)
            genre[GENRE_PLAYED_TRACKS] = row[0].to_i
            genre[GENRE_PLAYED_TIME] = row[1].to_i
            sql = "SELECT COUNT(rrecord), SUM(iplaytime) FROM records
                   WHERE rgenre=#{genre[GENRE_REF]} AND rmedia <> #{DBIntf::MEDIA_AUDIO_FILE};"
            row = DBIntf::connection.get_first_row(sql)
            genre[GENRE_TOT_RECS] = row[0].to_i
            genre[GENRE_TOT_RECTIME] = row[1].to_i
        end
    end

    def ripped_stats(genre)
        track_infos = TrackInfos.new
        DBIntf::connection.execute("SELECT rrecord FROM records WHERE rgenre=#{genre[GENRE_REF]} AND rmedia<>#{DBIntf::MEDIA_AUDIO_FILE}") do |record|
            Gtk.main_iteration while Gtk.events_pending?
            rtrack = DBIntf::connection.get_first_value("SELECT rtrack FROM tracks WHERE rrecord=#{record[0]};")
            if Utils::record_on_disk?(track_infos.get_track_infos(rtrack))
                genre[GENRE_RIPPED] += 1
                genre[GENRE_RIPTIME] += DBIntf::connection.get_first_value("SELECT iplaytime FROM records WHERE rrecord=#{record[0]};").to_i
            end
        end
        @genres[0][GENRE_RIPPED] += genre[GENRE_RIPPED]
        @genres[0][GENRE_RIPTIME] += genre[GENRE_RIPTIME]
    end

    def records_by_genre
        new_table("Ripped records", ["Genre", "Ripped", "Available", "Ripped play time", "Available play time"])
        @genres.each { |genre|
            next if genre[GENRE_REF] == 0
            new_row([genre[GENRE_NAME], genre[GENRE_RIPPED], genre[GENRE_TOT_RECS],
                     genre[GENRE_RIPTIME].to_day_length, genre[GENRE_TOT_RECTIME].to_day_length])
        }
        genre = @genres[0]
        new_row(["Total", genre[GENRE_RIPPED], genre[GENRE_TOT_RECS],
                 genre[GENRE_RIPTIME].to_day_length, genre[GENRE_TOT_RECTIME].to_day_length])
        end_table
    end

    def records_by_artists
        sql = "SELECT COUNT(records.rrecord) AS nrecs, SUM(records.iplaytime), artists.sname FROM artists
               INNER JOIN records ON artists.rartist=records.rartist
               GROUP BY artists.rartist ORDER BY nrecs DESC;"
        new_table("Records by artists", ["Rank", "Artist", "Records", "Play time"])
        DBIntf::connection.execute(sql) do |row|
            #Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[2], row[0], row[1].to_i.to_day_length])
        end
        end_table
    end

    def top_genres
        sql = "SELECT SUM(iplayed) AS totplayed, genres.sname, COUNT(iplayed) FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN genres ON records.rgenre=genres.rgenre
               WHERE iplayed > 0 GROUP BY records.rgenre ORDER BY totplayed DESC;"
        cols = []
        new_table("Music Style Top Chart", ["Rank", "Play count", "Genre", "Played", "Available", "% Played"]) # "Played/Available"])
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            genre = nil
            @genres.each { |g| if g.index(row[1]) then genre = g; break; end }
            cols = [@altr.counter+1, row[0], row[1]]
            unless genre.nil?
                cols += [row[2], genre[GENRE_TOT_TRACKS], "#{"%6.2f" % [row[2].to_f/genre[GENRE_TOT_TRACKS].to_f*100.0]}%"]
#                 cols += ["#{Utils::format_day_length(genre[GENRE_PLAYED_TIME])}/#{Utils::format_day_length(genre[GENRE_TOT_TIME])}"]
            end
            new_row(cols)
        end
        end_table
    end

    def top_artists(genre)
        sql = "SELECT SUM(iplayed) AS totplayed, artists.sname FROM tracks
               LEFT OUTER JOIN segments ON tracks.rsegment=segments.rsegment
               LEFT OUTER JOIN artists ON artists.rartist=segments.rartist
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord "

        if genre[GENRE_REF] == 0
            new_table("All Styles Artists Top Chart", ["Rank", "Play count", "Artist"])
            sql += "WHERE iplayed > 0 GROUP BY artists.rartist ORDER BY totplayed DESC;"
        else
            new_table("#{genre[GENRE_NAME]} Artists Top Chart", ["Rank", "Play count", "Artist"])
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} GROUP BY artists.rartist ORDER BY totplayed DESC;"
        end
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1]])
        end
        end_table
    end

    def top_records(genre)
        sql = "SELECT SUM(iplayed) AS totplayed, records.stitle, artists.sname FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN artists ON artists.rartist=records.rartist "

        if genre[GENRE_REF] == 0
            new_table("All Styles Records Top Chart", ["Rank", "Play count", "Record", "Artist"])
            sql += "WHERE iplayed > 0 GROUP BY records.rrecord ORDER BY totplayed DESC;"
        else
            new_table("#{genre[GENRE_NAME]} Records Top Chart", ["Rank", "Play count", "Record", "Artist"])
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} GROUP BY records.rrecord ORDER BY totplayed DESC;"
        end
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1], row[2]])
        end
        end_table
    end

    def top_tracks(genre)
        if genre[GENRE_REF] == 0
            new_table("All Styles Tracks Top Chart", ["Rank", "Play count", "Track", "Artist", "Record", "Segment"])
            sql = "SELECT rtrack, stitle, iplayed FROM tracks WHERE iplayed > 0 ORDER BY iplayed DESC;"
        else
            new_table("#{genre[GENRE_NAME]} Tracks Top Chart", ["Rank", "Play count", "Track", "Artist", "Record", "Segment"])
            sql = "SELECT tracks.rtrack, tracks.stitle, tracks.iplayed FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} ORDER BY iplayed DESC;"
        end
        track_infos = TrackInfos.new
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0].to_i)
            new_row([@altr.counter+1, row[2], row[1], track_infos.seg_art.sname,
                     track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table
    end

    def top_rated_tracks
        track_infos = TrackInfos.new
        new_table("Most rated tracks", ["Rank", "Rating", "Track", "Artist", "Record", "Segment"])
        DBIntf::connection.execute("SELECT rtrack, stitle, irating FROM tracks WHERE irating > 0 ORDER BY irating DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0])
            new_row([@altr.counter+1, UIConsts::RATINGS[row[2]], row[1], track_infos.seg_art.sname,
                     track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table
    end

    def gen_play_history
        limit = 1000
        track_infos = TrackInfos.new
        new_table("Last #{limit} played tracks", ["Order", "When", "Where", "Track", "Artist", "Record", "Segment"])
        sql = %Q{SELECT logtracks.rtrack, logtracks.idateplayed, hostnames.sname, records.rrecord, records.irecsymlink FROM logtracks
                 INNER JOIN hostnames ON hostnames.rhostname=logtracks.rhostname
                 INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                 INNER JOIN segments ON tracks.rsegment=segments.rsegment
                 INNER JOIN records ON records.rrecord=segments.rrecord
                 INNER JOIN artists ON artists.rartist=records.rartist
                 WHERE tracks.iplayed > 0
                 ORDER BY logtracks.idateplayed DESC LIMIT #{limit};}
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0])
            new_row([@altr.counter+1, Time.at(row[1].to_i), row[2], track_infos.track.stitle,
                     track_infos.seg_art.sname, track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table
    end

    def played_tracks_stats
        new_table("Played tracks")
        tot_played = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM logtracks")
        never_played = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE iplayed=0")
        diff_played = DBIntf::connection.get_first_value("SELECT COUNT(DISTINCT(rtrack)) FROM logtracks")
        new_row(["Played tracks total", tot_played])
        new_row(["Never played tracks", never_played])
        new_row(["Distinct played tracks", diff_played])
        DBIntf::connection.execute("SELECT * FROM hostnames") { |host|
            host_played = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM logtracks WHERE rhostname=#{host[0]}")
            new_row(["Played on #{host[1]}", host_played])
        }
        end_table
    end

    def rating_tags_stats
        sql = %{SELECT COUNT(tracks.rtrack) FROM tracks
                INNER JOIN records ON records.rrecord=tracks.rrecord
                WHERE records.rgenre NOT IN (1, 28);}
        tot_tracks = DBIntf.connection.get_first_value(sql)

        # Number and percentage of rated track
        sql = %{SELECT COUNT(tracks.rtrack) FROM tracks
                INNER JOIN records ON records.rrecord=tracks.rrecord
                WHERE tracks.irating<>0 AND records.rgenre NOT IN (1, 28);}
        tot_rated = DBIntf::connection.get_first_value(sql)
        new_table("Rated tracks", ["Rating", "# of tracks", "Percentage"])
        UIConsts::RATINGS.each_with_index { |rating, index|
            sql = %{SELECT COUNT(tracks.rtrack) FROM tracks
                    INNER JOIN records ON records.rrecord=tracks.rrecord
                    WHERE tracks.irating=#{index} AND records.rgenre NOT IN (1, 28);}
            rated = DBIntf::connection.get_first_value(sql)
#             new_row([rating, rated, "%6.2f" % [rated*100.0/@db_tots[DBTOTS_TRACKS]]])
            new_row([rating, rated, "%6.2f" % [rated*100.0/tot_tracks]])
        }
#         new_row(["Qualified total", tot_rated, "%6.2f" % [tot_rated*100.0/@db_tots[DBTOTS_TRACKS]]])
        new_row(["Qualified total", tot_rated, "%6.2f" % [tot_rated*100.0/tot_tracks]])
        new_row(["Tracks total", tot_tracks, ""])
        end_table

        sql = %{SELECT COUNT(logtracks.rtrack) FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN records ON records.rrecord=tracks.rrecord
                WHERE records.rgenre NOT IN (1, 28);}
        tot_played = DBIntf::connection.get_first_value(sql)

        # Number and percentage of played tracks by rating
        new_table("Played tracks by rating", ["Rating", "Played", "Percentage"])
        UIConsts::RATINGS.each_with_index { |rating, index|
#             played = DBIntf::connection.get_first_value("SELECT SUM(iplayed) FROM tracks WHERE irating=#{index};")
            sql = %{SELECT SUM(tracks.iplayed) FROM tracks
                    INNER JOIN records ON records.rrecord=tracks.rrecord
                    WHERE tracks.irating=#{index} AND records.rgenre NOT IN (1, 28);}
            played = DBIntf::connection.get_first_value(sql)
            played = 0 if played.nil?
            new_row([rating, played, "%6.2f" % [played*100.0/tot_played]])
        }
        new_row(["Tracks total", tot_played, ""])
        end_table

        # Number and percentage of tagged track
        sql = %{SELECT COUNT(tracks.rtrack) FROM tracks
                INNER JOIN records ON records.rrecord=tracks.rrecord
                WHERE tracks.itags<>0 AND records.rgenre NOT IN (1, 28);}
        tot_tagged = DBIntf::connection.get_first_value(sql)
        new_table("Tagged tracks", ["Tags", "# of tracks", "Percentage"])
        UIConsts::TAGS.each_with_index { |tag, index|
            sql = %{SELECT COUNT(tracks.rtrack) FROM tracks
                    INNER JOIN records ON records.rrecord=tracks.rrecord
                    WHERE (tracks.itags & #{1 << index})<>0 AND records.rgenre NOT IN (1, 28);}
            tagged = DBIntf::connection.get_first_value(sql)
#             new_row([tag, tagged, "%6.2f" % [tagged*100.0/@db_tots[DBTOTS_TRACKS]]])
            new_row([tag, tagged, "%6.2f" % [tagged*100.0/tot_tracks]])
        }
#         new_row(["Tagged total", tot_tagged, "%6.2f" % [tot_tagged*100.0/@db_tots[DBTOTS_TRACKS]]])
        new_row(["Tagged total", tot_tagged, "%6.2f" % [tot_tagged*100.0/tot_tracks]])
        new_row(["Tracks total", tot_tracks, ""])
        end_table

        # Number and percentil of played tracks by tag
        new_table("Played tracks by tag", ["Tags", "Played", "Percentage"])
        UIConsts::TAGS.each_with_index { |tag, index|
            sql = %{SELECT SUM(tracks.iplayed) FROM tracks
                    INNER JOIN records ON records.rrecord=tracks.rrecord
                    WHERE (tracks.itags & #{1 << index}) <> 0 AND records.rgenre NOT IN (1, 28);}
#             played = DBIntf::connection.get_first_value("SELECT SUM(iplayed) FROM tracks WHERE (itags & #{1 << index})<>0;")
            played = DBIntf::connection.get_first_value(sql)
            played = 0 if played.nil?
            new_row([tag, played, "%6.2f" % [played*100.0/tot_played]])
        }
        new_row(["Tracks total", tot_played, ""])
        end_table
    end

    def charts_by_artists
        @genres.each { |genre| top_artists(genre) }
    end

    def charts_by_records
        @genres.each { |genre| top_records(genre) }
    end

    def charts_by_tracks
        @genres.each { |genre| top_tracks(genre) }
    end

    def cleanup
        @f << "</body></html>"
        @f.close
    end

    def db_stats
        glade = GTBld::load(UIConsts::DLG_STATS)
        tv = glade[UIConsts::STATS_TV]

        tv.model = Gtk::ListStore.new(TrueClass, String)

        arenderer = Gtk::CellRendererToggle.new
        arenderer.activatable = true
        arenderer.signal_connect(:toggled) { |w, path|
            iter = tv.model.get_iter(path)
            iter[0] = !iter[0] if (iter)
        }
        srenderer = Gtk::CellRendererText.new()

        tv.append_column(Gtk::TreeViewColumn.new("Select", arenderer, :active => 0))
        tv.append_column(Gtk::TreeViewColumn.new("Stat", srenderer, :text => 1))
        TV_ITEMS.each { |key, value|
            iter = tv.model.append
            iter[0] = false
            iter[1] = key
        }

        if glade[UIConsts::DLG_STATS].run != Gtk::Dialog::RESPONSE_OK
            glade[UIConsts::DLG_STATS].destroy
            return
        end

        init_globals(Cfg::instance.rsrc_dir+"dbstats.html", "DB Statistics")
        db_general_infos

        # Check to see if a selection needs the ripped records data
        tv.model.each { |model, path, iter|
            if iter[0] && TV_ITEMS[iter[1]][0]
                @genres.each { |genre| ripped_stats(genre) if genre[0] != 0 }
                break
            end
        }

        tv.model.each { |model, path, iter|
            self.send(TV_ITEMS[iter[1]][1]) if iter[0]
        }

        cleanup

        glade[UIConsts::DLG_STATS].destroy
    end

end