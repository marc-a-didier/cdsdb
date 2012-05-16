
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

    def initialize(mc)
        @mc = mc
    end

    def get_count(stbl)
        return DBIntf::connection.get_first_value("SELECT COUNT(r#{stbl}) FROM #{stbl}s;")
    end

    def init_globals(fname, title)
        op_id = @mc.tasks.new_progress("Collecting basic infos")
        @f = File.new(fname, "w")
        @f << "<html><head>"
        @f << "<title>#{title}</title>"
        @f << "</head><body>"
        @f << '<style type="text/css">'
        @f << 'h1 {font-size: 18px; font-family: "sans";}'
        @f << 'h2 {font-size: 16px; font-family: "sans";}'
        @f << 'p {font-size: 10px; font-family: "sans";}'
        @f << 'td {font-size: 10px; font-family: "sans";}'
        @f << '</style>'

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

        #@f << "\nDB statistics\n"
        #@f << "=============\n\n"
        @f << '<h1>General infos</h1><br /><p>'
        @f << '<table border="1">'
        @f << "<tr><td>Total number of artists</td><td>#{@db_tots[DBTOTS_ARTISTS]}</td></tr>"
        @f << "<tr><td>Total number of records</td><td>#{@db_tots[DBTOTS_RECORDS]} - Play time: #{Utils::format_day_length(@db_tots[DBTOTS_PTIME])}</td></tr>"
        @f << "<tr><td>Total number of segments</td><td>#{@db_tots[DBTOTS_SEGS]}</td></tr>"
        @f << "<tr><td>Total number of tracks</td><td>#{@db_tots[DBTOTS_TRACKS]}</td></tr>"
        @f << "</table></p><hr /><br /><br />"


        @f << "<h2>Records by media type</h2><br /><p>"
        @f << '<table border="1">'
        DBIntf::connection.execute("SELECT * FROM medias;") do |mediatype|
            DBIntf::connection.execute("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia=#{mediatype[0]};") do |row|
                #Gtk.main_iteration while Gtk.events_pending?
                @mc.tasks.update_progress(op_id)
                @media[mediatype[1]] = [row[0], row[1]]
                @f << "<tr><td>#{mediatype[1]}</td><td>#{row[0]} records for #{Utils::format_day_length(row[1].to_i)}</td></tr>"
            end
        end
        @f << "</table></p><hr /><br /><br />"
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
        @f << '<table border="1">'
        @genres.each { |genre|
            next if genre[GENRE_REF] == 0
            @f << "<tr><td>#{genre[GENRE_NAME]}</td>"
            @f << "<td>#{genre[GENRE_RIPPED]}/#{genre[GENRE_TOT_RECS]}</td><td>#{Utils::format_day_length(genre[GENRE_RIPTIME])}/#{Utils::format_day_length(genre[GENRE_TOT_RECTIME])}</td></tr>"
        }
        genre = @genres[0]
        @f << "<tr><td>Total</td><td>#{genre[GENRE_RIPPED]}/#{genre[GENRE_TOT_RECS]}</td><td>#{Utils::format_day_length(genre[GENRE_RIPTIME])}/#{Utils::format_day_length(genre[GENRE_TOT_RECTIME])}</td></tr>"
        @f << "</table></p><hr /><br /><br />"
    end

    def records_by_artists
        op_id = @mc.tasks.new_progress("Records by artists")
        sql = "SELECT COUNT(records.rrecord) AS nrecs, SUM(records.iplaytime), artists.sname FROM artists
               INNER JOIN records ON artists.rartist=records.rartist
               GROUP BY artists.rartist ORDER BY nrecs DESC;"
        @f << '<h2>Records by artists</h2><br /><p>'
        @f << '<table border="1">'
        pos = 0
        DBIntf::connection.execute(sql) do |row|
            #Gtk.main_iteration while Gtk.events_pending?
            @mc.tasks.update_progress(op_id)
            pos += 1
            @f << "<tr><td>#{pos}</td><td>#{row[2]}</td><td>#{row[0]}</td><td>#{Utils::format_day_length(row[1].to_i)}</td></tr>"
        end
        @f << "</table></p><hr /><br /><br />"
        @mc.tasks.end_progress(op_id)
    end

    def top_genres
        pos = 0
        @f << '<h2>Music Style Top Chart</h2><br /><p>'
        @f << '<table border="1">'
        sql = "SELECT SUM(iplayed) AS totplayed, genres.sname, COUNT(iplayed) FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN genres ON records.rgenre=genres.rgenre
               WHERE iplayed > 0 GROUP BY records.rgenre ORDER BY totplayed DESC;"
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            genre = nil
            @genres.each { |g| if g.index(row[1]) then genre = g; break; end }
            @f << "<tr><td>#{pos}</td><td>#{row[0]}</td><td>#{row[1]}</td>"
            unless genre.nil?
                @f << "<td>#{row[2]}/#{genre[GENRE_TOT_TRACKS]}</td><td>#{"%6.2f" % [row[2].to_f/genre[GENRE_TOT_TRACKS].to_f*100.0]}%</td>"
                @f << "<td>#{Utils::format_day_length(genre[GENRE_PLAYED_TIME])}/#{Utils::format_day_length(genre[GENRE_TOT_TIME])}</td>"
                @f << "</tr>"
            end
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def top_artists(genre)
        pos = 0
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
        @f << '<table border="1">'
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            @f << "<tr><td>#{pos}</td><td>#{row[0].to_i}</td><td>#{row[1]}</td></tr>"
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def top_records(genre)
        pos = 0
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
        @f << '<table border="1">'
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            @f << "<tr><td>#{pos}</td><td>#{row[0]}</td><td>#{row[1]}</td><td>#{row[2]}</td></tr>"
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def top_tracks(genre)
        pos = 0
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
        @f << '<table border="1">'
        DBIntf::connection.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            track_infos.load_track(row[0].to_i)
            @f << "<tr>"
            @f << "<td>#{pos}</td><td>#{row[2]}</td><td>#{row[1]}</td><td>#{track_infos.seg_art.sname}</td><td>#{track_infos.record.stitle}</td>"
            @f << "<td>#{track_infos.segment.stitle}</td>" unless track_infos.segment.stitle.empty?
            @f << "</tr>"
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def top_rated_tracks
        pos = 0
        track_infos = TrackInfos.new
        @f << '<h2>Most rated tracks</h2><br /><p>'
        @f << '<table border="1">'
        DBIntf::connection.execute("SELECT rtrack, stitle, irating FROM tracks WHERE irating > 0 ORDER BY irating DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            track_infos.load_track(row[0])
            @f << "<tr><td>#{pos}</td><td>#{Cdsdb::RATINGS[row[2]]}</td><td>#{row[1]}</td><td>#{track_infos.seg_art.sname}</td><td>#{track_infos.record.stitle}</td>"
            @f << "<td>#{track_infos.segment.stitle}</td>)" unless track_info.segment.stitle.empty?
            @f << "</tr>"
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def gen_play_history
        pos = 0
        track_infos = TrackInfos.new
        @f << '<h2>Play history</h2><br /><p>'
        @f << '<table border="1">'
        DBIntf::connection.execute("SELECT rtrack, stitle, ilastplayed FROM tracks WHERE ilastplayed > 0 ORDER BY ilastplayed DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            pos += 1
            track_infos.load_track(row[0])
            @f << "<tr><td>#{pos}</td><td>#{Time.at(row[2])}</td><td>#{row[1]}</td><td>#{track_infos.seg_art.sname}</td><td>#{track_infos.record.stitle}</td>"
            @f << "<td>#{track_infos.segment.stitle}</td>)" unless track_info.segment.stitle.empty?
            @f << "</tr>"
        end
        @f << "</table></p><hr /><br /><br />"
    end

    def cleanup
        @f << "</body></html>"
        @f.close
    end

    def db_stats
        init_globals(Cfg::instance.rsrc_dir+"dbstats.html", "DB Statistics")
        db_general_infos

        @genres.each { |genre| ripped_stats(genre) if genre[0] != 0 }
        records_by_genre
        records_by_artists

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