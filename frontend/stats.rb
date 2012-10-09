
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

    def new_table
        @f << '<table id="mytbl">'
        @altr.reset
    end

    def new_row(cols)
        @f << @altr.get_color
        cols.each { |col_title| @f << "<td>"+col_title.to_s+"</td>" }
        @f << "</tr>"
    end

    def end_table(html_epilogue = "")
        @f << "</table>"+html_epilogue
    end

    def get_count(stbl)
        return DBIntf::connection.get_first_value("SELECT COUNT(r#{stbl}) FROM #{stbl}s;")
    end

    def init_globals(fname, title)
        op_id = @mc.tasks.new_progress("Collecting basic infos")
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
        DBIntf::connection.execute("SELECT * FROM genres ORDER BY sname;") { |row| @genres << [row[0], row[1], 0, 0, 0, 0, 0, 0, 0, 0] }
        @genres.each { |genre| @mc.tasks.update_progress(op_id); init_table(genre) }
        @genres.delete_if { |genre| genre[GENRE_TOT_TRACKS] == 0 } # Remove genres with no tracks
        @mc.tasks.end_progress(op_id)
    end

    def db_general_infos
        op_id = @mc.tasks.new_progress("General infos")

        @f << '<h1>General infos</h1><br /><p>'
        new_table
        new_row(["Total number of artists", @db_tots[DBTOTS_ARTISTS]])
        new_row(["Total number of records", "#{@db_tots[DBTOTS_RECORDS]} - Play time: #{Utils::format_day_length(@db_tots[DBTOTS_PTIME])}"])
        new_row(["Total number of segments", @db_tots[DBTOTS_SEGS]])
        new_row(["Total number of tracks", @db_tots[DBTOTS_TRACKS]])
        end_table("</p><hr /><br /><br />")

        @f << "<h2>Records by media type</h2><br /><p>"
        new_table
        DBIntf::connection.execute("SELECT * FROM medias;") do |mediatype|
            DBIntf::connection.execute("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia=#{mediatype[0]};") do |row|
                #Gtk.main_iteration while Gtk.events_pending?
                @mc.tasks.update_progress(op_id)
                @media[mediatype[1]] = [row[0], row[1]]
                new_row([mediatype[1], "#{row[0]} records", Utils::format_day_length(row[1].to_i)])
            end
        end
        end_table("</p><hr /><br /><br />")

        @mc.tasks.end_progress(op_id)
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
        @f << '<h2>Ripped records</h2><br /><p>'
        new_table
        @genres.each { |genre|
            next if genre[GENRE_REF] == 0
            new_row([genre[GENRE_NAME], "#{genre[GENRE_RIPPED]}/#{genre[GENRE_TOT_RECS]}",
                     Utils::format_day_length(genre[GENRE_RIPTIME]), Utils::format_day_length(genre[GENRE_TOT_RECTIME])])
        }
        genre = @genres[0]
        new_row(["Total", "#{genre[GENRE_RIPPED]}/#{genre[GENRE_TOT_RECS]}",
                 Utils::format_day_length(genre[GENRE_RIPTIME]), Utils::format_day_length(genre[GENRE_TOT_RECTIME])])
        end_table("</p><hr /><br /><br />")
    end

    def records_by_artists
        op_id = @mc.tasks.new_progress("Records by artists")
        sql = "SELECT COUNT(records.rrecord) AS nrecs, SUM(records.iplaytime), artists.sname FROM artists
               INNER JOIN records ON artists.rartist=records.rartist
               GROUP BY artists.rartist ORDER BY nrecs DESC;"
        @f << '<h2>Records by artists</h2><br /><p>'
        new_table
        DBIntf::connection.execute(sql) do |row|
            #Gtk.main_iteration while Gtk.events_pending?
            @mc.tasks.update_progress(op_id)
            new_row([@altr.counter+1, row[2], row[0], Utils::format_day_length(row[1].to_i)])
        end
        end_table("</p><hr /><br /><br />")
        @mc.tasks.end_progress(op_id)
    end

    def top_genres
        @f << '<h2>Music Style Top Chart</h2><br /><p>'
        sql = "SELECT SUM(iplayed) AS totplayed, genres.sname, COUNT(iplayed) FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN genres ON records.rgenre=genres.rgenre
               WHERE iplayed > 0 GROUP BY records.rgenre ORDER BY totplayed DESC;"
        cols = []
        new_table
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            genre = nil
            @genres.each { |g| if g.index(row[1]) then genre = g; break; end }
            cols = [@altr.counter+1, row[0], row[1]]
            unless genre.nil?
                cols += ["#{row[2]}/#{genre[GENRE_TOT_TRACKS]}", "#{"%6.2f" % [row[2].to_f/genre[GENRE_TOT_TRACKS].to_f*100.0]}%"]
                cols += ["#{Utils::format_day_length(genre[GENRE_PLAYED_TIME])}/#{Utils::format_day_length(genre[GENRE_TOT_TIME])}"]
            end
            new_row(cols)
        end
        end_table("</p><hr /><br /><br />")
    end

    def top_artists(genre)
        sql = "SELECT SUM(iplayed) AS totplayed, artists.sname FROM tracks
               LEFT OUTER JOIN segments ON tracks.rsegment=segments.rsegment
               LEFT OUTER JOIN artists ON artists.rartist=segments.rartist
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord "

        if genre[GENRE_REF] == 0
            @f << "<h2>All Styles Artists Top Chart</h2><br /><p>"
            sql += "WHERE iplayed > 0 GROUP BY artists.rartist ORDER BY totplayed DESC;"
        else
            @f << "<h2>#{genre[GENRE_NAME]} Artists Top Chart</h2><br /><p>"
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} GROUP BY artists.rartist ORDER BY totplayed DESC;"
        end
        new_table
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1]])
        end
        end_table("</p><hr /><br /><br />")
    end

    def top_records(genre)
        sql = "SELECT SUM(iplayed) AS totplayed, records.stitle, artists.sname FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN artists ON artists.rartist=records.rartist "

        if genre[GENRE_REF] == 0
            @f << "<h2>All Styles Records Top Chart</h2><br /><p>"
            sql += "WHERE iplayed > 0 GROUP BY records.rrecord ORDER BY totplayed DESC;"
        else
            @f << "<h2>#{genre[GENRE_NAME]} Records Top Chart</h2><br /><p>"
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} GROUP BY records.rrecord ORDER BY totplayed DESC;"
        end
        new_table
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1], row[2]])
        end
        end_table("</p><hr /><br /><br />")
    end

    def top_tracks(genre)
        if genre[GENRE_REF] == 0
            @f << "<h2>All Styles Tracks Top Chart</h2><br /><p>"
            sql = "SELECT rtrack, stitle, iplayed FROM tracks WHERE iplayed > 0 ORDER BY iplayed DESC;"
        else
            @f << "<h2>#{genre[GENRE_NAME]} Tracks Top Chart</h2><br /><p>"
            sql = "SELECT tracks.rtrack, tracks.stitle, tracks.iplayed FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre[GENRE_REF]} ORDER BY iplayed DESC;"
        end
        track_infos = TrackInfos.new
        new_table
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0].to_i)
            new_row([@altr.counter+1, row[2], row[1], track_infos.seg_art.sname,
                     track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table("</p><hr /><br /><br />")
    end

    def top_rated_tracks
        track_infos = TrackInfos.new
        @f << '<h2>Most rated tracks</h2><br /><p>'
        new_table
        DBIntf::connection.execute("SELECT rtrack, stitle, irating FROM tracks WHERE irating > 0 ORDER BY irating DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0])
            new_row([@altr.counter+1, Cdsdb::RATINGS[row[2]], row[1], track_infos.seg_art.sname,
                     track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table("</p><hr /><br /><br />")
    end

    def gen_play_history
        track_infos = TrackInfos.new
        @f << '<h2>Play history</h2><br /><p>'
        new_table
        DBIntf::connection.execute("SELECT rtrack, stitle, ilastplayed FROM tracks WHERE ilastplayed > 0 ORDER BY ilastplayed DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            track_infos.load_track(row[0])
            new_row([@altr.counter+1, Time.at(row[2]), row[1], track_infos.seg_art.sname,
                     track_infos.record.stitle, track_infos.segment.stitle])
        end
        end_table("</p><hr /><br /><br />")
    end

    def played_tracks_stats
        @f << '<h2>Played tracks</h2><br /><p>'
        new_table
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
        end_table("</p><hr /><br /><br />")
    end

    def cleanup
        @f << "</body></html>"
        @f.close
    end

    def db_stats
        init_globals(Cfg::instance.rsrc_dir+"dbstats.html", "DB Statistics")
        db_general_infos

        played_tracks_stats
        @genres.each { |genre| ripped_stats(genre) if genre[0] != 0 }
#         records_by_genre
#         records_by_artists
        top_genres

        cleanup
    end

    def top_charts
        init_globals(Cfg::instance.rsrc_dir+"charts.html", "Top Charts")
        top_genres
        @genres.each { |genre| top_artists(genre) }
        @genres.each { |genre| top_records(genre) }
        @genres.each { |genre| top_tracks(genre) }
        cleanup
    end

    def play_history
        init_globals(Cfg::instance.rsrc_dir+"playhistory.html", "Play History")
        gen_play_history
        cleanup
    end

    def ratings_stats
        init_globals(Cfg::instance.rsrc_dir+"ratings.html", "Top Ratings")
        top_rated_tracks
        cleanup
    end

    def generate_stats
        init_globals(Cfg::instance.rsrc_dir+"stats.html", "Global Statistics")
        db_general_infos

        @genres.each { |genre| ripped_stats(genre) if genre[0] != 0 }
        records_by_genre
        records_by_artists

        top_genres
        @genres.each { |genre| top_artists(genre) }
        @genres.each { |genre| top_records(genre) }
        @genres.each { |genre| top_tracks(genre) }

        top_rated_tracks
        play_history

        cleanup
    end

end