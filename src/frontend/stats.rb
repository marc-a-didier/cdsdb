
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

    GenreStruct = Struct.new(:ref, :name, :tot_time, :tot_tracks, :played_time, :played_tracks,
                             :tot_recs, :tot_rectime, :ripped, :riptime) do
        def init
            self.size.times { |i| self[i] = 0 if self[i].nil? && i != 1 }
            return self
        end
    end

    DBTotals = Struct.new(:artists, :records, :segments, :tracks, :ptime, :played, :tot_ptime)


    TV_ITEMS = {"Played tracks" => [false, :played_tracks_stats],
                "Rated and tagged tracks" => [false, :rating_tags_stats],
                "Played tracks by genre" => [false, :played_by_genre],

                "Records by artists" => [false,  :records_by_artists],
                "Records by genres" => [true, :records_by_genre],

                "Last 1000 played" => [false, :gen_play_history],

                "Charts by genre" => [false, :top_genres],
                "Charts by genre & artists" => [false, :charts_by_artists],
                "Charts by genre & records" => [false, :charts_by_records],
                "Charts by genre & tracks" => [false, :charts_by_tracks],

                "List of rated tracks" => [false, :top_rated_tracks] }

    # SQL filter for sorting classic/baroque/gregorian out of selection
    NO_CBG = "records.rgenre NOT IN (1, 28, 41)"

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
        @tables << "<h1>" << title << "</h1><br />"
        @tables << '<table id="mytbl">'
        @altr.reset
        @alignments = []
        headers.each { |header|
            @alignments << (header.match(/:R$/) ? "r" : "l")
            @tables << "<th>" << header.sub(/:R$/, "") << "</th>"
        }
    end

    def new_row(cols)
        @tables << @altr.get_color
        cols.each_with_index { |col_title, i|
            align = @alignments[i] && @alignments[i] == "r" ? '<td class="alt">' : '<td>'
            @tables << align << col_title.to_s << '</td>'
        }
        @tables << "</tr>\n"
    end

    def end_table(html_epilogue = "")
        @tables << "</table><hr /><br /><br />"+html_epilogue
    end

    def get_count(stbl)
        return DBIntf.get_first_value("SELECT COUNT(r#{stbl}) FROM #{stbl}s;")
    end

    def init_globals(fname, title)
#         @f = File.new(fname, "w")
#         @f << "<!DOCTYPE html><head>"
#         @f << '<meta charset="UTF-8">'
#         @f << "<title>#{title}</title>"
#         @f << %{<style type="text/css">
#                 h1 {font-size: 18px; font-family: "sans";}
#                 h2 {font-size: 16px; font-family: "sans";}
#                 p {font-size: 10px; font-family: "sans";}
#                 #mytbl
#                 {
#                     font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
#                     border-collapse:collapse;
#                 }
#                 #mytbl td, #mytbl th
#                 {
#                     font-size:1em;
#                     border:1px solid #98bf21;
#                     padding:3px 7px 2px 7px;
#                 }
#                 #mytbl th
#                 {
#                     font-size:1.1em;
#                     text-align:left;
#                     padding-top:5px;
#                     padding-bottom:4px;
#                     background-color:#A7C942;
#                     color:#ffffff;
#                 }
#                 #mytbl tr.alt td
#                 {
#                     color:#000000;
#                     background-color:#B5DDF7;
#                 }
#                 #mytbl td.alt
#                 {
#                     text-align:right;
#                 }
#                 }
#                     background-color:#EAF2D3;
#         @f << '</style></head><body>'

        @tables = ''

#         @genres = []
        @db_tots = DBTotals.new
        @media = Hash.new

        # Initialize db totals
        %w[artist record segment track].each_with_index { |table, i| @db_tots[i] = get_count(table) }
        @db_tots.ptime = DBIntf.get_first_value("SELECT SUM(iplaytime) FROM records;").to_i
        @db_tots.played = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks;")
        @db_tots.tot_ptime = DBIntf.get_first_value("SELECT SUM(iplayed*iplaytime) FROM tracks WHERE iplayed > 0;")

        # @genres is an array of GenreStruct. @genres[0] is the global total of all genres
        # Initialize totals by genres
        @genres = Array.new(1, GenreStruct.new.init)
        DBIntf.execute("SELECT * FROM genres WHERE rgenre<>0 ORDER BY sname;") { |row| @genres << GenreStruct.new(row[0], row[1]).init }
        @genres.each { |genre| init_table(genre) }
        @genres.delete_if { |genre| genre.tot_tracks == 0 } # Remove genres with no tracks
    end

    def db_general_infos
        @tables << "<h1>DB stats generated #{Time.now}</h1><br />"
        new_table("General infos")
        new_row(["Total number of artists", @db_tots.artists])
        new_row(["Total number of records", "#{@db_tots.records} - Duration: #{@db_tots.ptime.to_day_length}"])
        new_row(["Total number of segments", @db_tots.segments])
        new_row(["Total number of tracks", @db_tots.tracks])
        end_table

        new_table("Records by media type", ["Medium", "Records:R", "Duration:R"])
        DBIntf.execute("SELECT * FROM medias;") do |mediatype|
            DBIntf.execute("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia=#{mediatype[0]};") do |row|
                #Gtk.main_iteration while Gtk.events_pending?
                @media[mediatype[1]] = [row[0], row[1]]
                new_row([mediatype[1], row[0], row[1].to_i.to_day_length])
            end
        end
        end_table
    end

    def init_table(genre)
        if genre.ref == 0
            row = DBIntf.get_first_row("SELECT COUNT(rtrack), SUM(iplaytime) FROM tracks;")
            genre.tot_tracks = row[0].to_i
            genre.tot_time = row[1].to_i
            row = DBIntf.get_first_row("SELECT SUM(iplayed), SUM(iplayed*iplaytime) FROM tracks WHERE iplayed > 0;")
            genre.played_tracks = row[0].to_i
            genre.played_time = row[1].to_i
            row = DBIntf.get_first_row("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia <> #{Audio::MEDIA_FILE}")
            genre.tot_recs = row[0].to_i
            genre.tot_rectime = row[1].to_i
        else
            sql = "SELECT COUNT(tracks.rtrack), SUM(tracks.iplaytime) FROM tracks
                   INNER JOIN records ON records.rrecord=tracks.rrecord
                   WHERE records.rgenre=#{genre.ref};"
            row = DBIntf.get_first_row(sql)
            genre.tot_tracks = row[0].to_i
            genre.tot_time = row[1].to_i
            sql = "SELECT SUM(tracks.iplayed), SUM(tracks.iplaytime*tracks.iplayed) FROM tracks
                   INNER JOIN records ON records.rrecord=tracks.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre.ref};"
            row = DBIntf.get_first_row(sql)
            genre.played_tracks = row[0].to_i
            genre.played_time = row[1].to_i
            sql = "SELECT COUNT(rrecord), SUM(iplaytime) FROM records
                   WHERE rgenre=#{genre.ref} AND rmedia <> #{Audio::MEDIA_FILE};"
            row = DBIntf.get_first_row(sql)
            genre.tot_recs = row[0].to_i
            genre.tot_rectime = row[1].to_i
        end
    end

    def ripped_stats(genre)
        audio_link = Audio::Link.new
        DBIntf.execute("SELECT rrecord FROM records WHERE rgenre=#{genre.ref} AND rmedia<>#{Audio::MEDIA_FILE}") do |record|
            Gtk.main_iteration while Gtk.events_pending?
            rtrack = DBIntf.get_first_value("SELECT rtrack FROM tracks WHERE rrecord=#{record[0]};")
            if audio_link.reset.set_track_ref(rtrack).record_on_disk?
                genre.ripped += 1
                genre.riptime += DBIntf.get_first_value("SELECT iplaytime FROM records WHERE rrecord=#{record[0]};").to_i
            end
        end
        @genres[0].ripped += genre.ripped
        @genres[0].riptime += genre.riptime
    end

    def records_by_genre
        new_table("Ripped records", ["Genre", "Ripped:R", "Available:R", "Ripped duration:R", "Available duration:R"])
        @genres.each { |genre|
            next if genre.ref == 0
            new_row([genre.name, genre.ripped, genre.tot_recs,
                     genre.riptime.to_day_length, genre.tot_rectime.to_day_length])
        }
        genre = @genres[0]
        new_row(["Total", genre.ripped, genre.tot_recs,
                 genre.riptime.to_day_length, genre.tot_rectime.to_day_length])
        end_table
    end

    def records_by_artists
        sql = "SELECT COUNT(records.rrecord) AS nrecs, SUM(records.iplaytime), artists.sname FROM artists
               INNER JOIN records ON artists.rartist=records.rartist
               GROUP BY artists.rartist ORDER BY nrecs DESC;"
        new_table("Records by artists", ["Rank:R", "Artist", "Records:R", "Duration:R"])
        DBIntf.execute(sql) do |row|
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
        new_table("Music Style Top Chart", ["Rank:R", "Play count:R", "Genre", "Played:R", "Available:R", "% Played:R"])
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            genre = @genres.detect { |g| g.index(row[1]) }
            cols = [@altr.counter+1, row[0], row[1]]
            unless genre.nil?
                cols += [row[2], genre.tot_tracks, "#{"%6.2f" % [row[2].to_f/genre.tot_tracks.to_f*100.0]}%"]
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

        if genre.ref == 0
            new_table("All Styles Artists Top Chart", ["Rank:R", "Play count:R", "Artist"])
            sql += "WHERE iplayed > 0 GROUP BY artists.rartist ORDER BY totplayed DESC;"
        else
            new_table("#{genre.name} Artists Top Chart", ["Rank:R", "Play count:R", "Artist"])
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre.ref} GROUP BY artists.rartist ORDER BY totplayed DESC;"
        end
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1]])
        end
        end_table
    end

    def top_records(genre)
        sql = "SELECT SUM(iplayed) AS totplayed, records.stitle, artists.sname FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN artists ON artists.rartist=records.rartist "

        if genre.ref == 0
            new_table("All Styles Records Top Chart", ["Rank:R", "Play count:R", "Record", "Artist"])
            sql += "WHERE iplayed > 0 GROUP BY records.rrecord ORDER BY totplayed DESC;"
        else
            new_table("#{genre.name} Records Top Chart", ["Rank:R", "Play count:R", "Record", "Artist"])
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre.ref} GROUP BY records.rrecord ORDER BY totplayed DESC;"
        end
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            new_row([@altr.counter+1, row[0], row[1], row[2]])
        end
        end_table
    end

    def top_tracks(genre)
        if genre.ref == 0
            new_table("All Styles Tracks Top Chart", ["Rank:R", "Play count:R", "Track", "Artist", "Record", "Segment"])
            sql = "SELECT rtrack, stitle, iplayed FROM tracks WHERE iplayed > 0 ORDER BY iplayed DESC;"
        else
            new_table("#{genre.name} Tracks Top Chart", ["Rank:R", "Play count:R", "Track", "Artist", "Record", "Segment"])
            sql = "SELECT tracks.rtrack, tracks.stitle, tracks.iplayed FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre.ref} ORDER BY iplayed DESC;"
        end
        audio_link = Audio::Link.new
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            audio_link.reset.set_track_ref(row[0].to_i)
            new_row([@altr.counter+1, row[2], row[1], audio_link.segment_artist.sname,
                     audio_link.record.stitle, audio_link.segment.stitle])
        end
        end_table
    end

    def top_rated_tracks
        audio_link = Audio::Link.new
        new_table("Most rated tracks", ["Rank:R", "Rating", "Track", "Artist", "Record", "Segment"])
        DBIntf.execute("SELECT rtrack, stitle, irating FROM tracks WHERE irating > 0 ORDER BY irating DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            audio_link.reset.set_track_ref(row[0])
            new_row([@altr.counter+1, Qualifiers::RATINGS[row[2]], row[1], audio_link.segment_artist.sname,
                     audio_link.record.stitle, audio_link.segment.stitle])
        end
        end_table
    end

    def gen_play_history
        limit = 1000
        audio_link = Audio::Link.new
        new_table("Last #{limit} played tracks", ["Order:R", "When", "Where", "Track", "Artist", "Record", "Segment"])
        sql = %Q{SELECT logtracks.rtrack, logtracks.idateplayed, hosts.sname, records.rrecord, records.irecsymlink FROM logtracks
                 INNER JOIN hosts ON hosts.rhost=logtracks.rhost
                 INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                 INNER JOIN segments ON tracks.rsegment=segments.rsegment
                 INNER JOIN records ON records.rrecord=segments.rrecord
                 INNER JOIN artists ON artists.rartist=records.rartist
                 WHERE tracks.iplayed > 0
                 ORDER BY logtracks.idateplayed DESC LIMIT #{limit};}
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            audio_link.reset.set_track_ref(row[0])
            new_row([@altr.counter+1, Time.at(row[1].to_i), row[2], audio_link.track.stitle,
                     audio_link.segment_artist.sname, audio_link.record.stitle, audio_link.segment.stitle])
        end
        end_table
    end

    def played_tracks_stats
        new_table("Played tracks", ["", ":R"])
        tot_played = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks")
        never_played = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE iplayed=0")
        diff_played = DBIntf.get_first_value("SELECT COUNT(DISTINCT(rtrack)) FROM logtracks")
        new_row(["Played tracks total", tot_played])
        new_row(["Never played tracks", never_played])
        new_row(["Distinct played tracks", diff_played])
        DBIntf.execute("SELECT * FROM hosts") { |host|
            host_played = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks WHERE rhost=#{host[0]}")
            new_row(["Played on #{host[1]}", host_played])
        }
        end_table
    end

    def rating_tags_stats

        def exec_filtered_sql(filter)
            filter = filter.empty? ? NO_CBG : filter+" AND #{NO_CBG}"
            sql = %{SELECT COUNT(tracks.rtrack), SUM(tracks.iplayed), SUM(tracks.iplayed*tracks.iplaytime) FROM tracks
                    INNER JOIN records ON records.rrecord=tracks.rrecord
                    WHERE #{filter};}
            return DBIntf.get_first_row(sql)
        end

        def gen_table(title, first_col)
            new_table(title+" tracks without Classical/Baroque",
                      [first_col, "# of tracks:R", "Percentage:R", "Played:R", "Percentage:R",
                       "Played time:R", "Percentage:R"])
        end

        def gen_row(title, data_row, tot_row)
            new_row([title,
                     data_row[0], "%6.2f" % [data_row[0]*100.0/tot_row[0]],
                     data_row[1], "%6.2f" % [data_row[1]*100.0/tot_row[1]],
                     data_row[2].to_day_length, "%6.2f" % [data_row[2]*100.0/tot_row[2]]])
        end

        # Total tracks, played tracks and total playtime without classic.
        # Valid for both rating and tags.
        tot_row = exec_filtered_sql("")

        #
        # Ratings
        #

        tot_rated_row = exec_filtered_sql("tracks.irating<>0")
        tot_unrated_row = exec_filtered_sql("tracks.irating=0")

        gen_table("Rated", "Rating")
        (1..6).each { |index|
            data_row = exec_filtered_sql("tracks.irating=#{index}")

            gen_row(Qualifiers::RATINGS[index], data_row, tot_row)
        }
        gen_row("Qualified", tot_rated_row, tot_row)
        gen_row("Unqualified", tot_unrated_row, tot_row)

        3.times { |i| tot_rated_row[i] += tot_unrated_row[i] }
        gen_row("Tracks", tot_rated_row, tot_row)

        end_table

        #
        # Tags
        #
        tot_tagged_row = exec_filtered_sql("tracks.itags<>0")
        tot_untagged_row = exec_filtered_sql("tracks.itags=0")

        gen_table("Tagged", "Tag")
        Qualifiers::TAGS.each_with_index { |tag, index|
            data_row = exec_filtered_sql("(tracks.itags & #{1 << index}) <> 0")

            gen_row(tag, data_row, tot_row)
        }
        gen_row("Tagged", tot_tagged_row, tot_row)
        gen_row("Untagged", tot_untagged_row, tot_row)

        3.times { |i| tot_tagged_row[i] += tot_untagged_row[i] }
        gen_row("Tracks", tot_tagged_row, tot_row)

        end_table
    end

    def played_by_genre
        new_table("Played tracks by genre", ["Genre", "# of tracks:R", "Percentage:R", "Played:R", "Percentage:R", "Played time:R", "Percentage:R"])
        @genres.each_with_index do |genre, i|
            next if i == 0
            new_row([genre.name, genre.tot_tracks, "%6.2f" % [genre.tot_tracks*100.0/@db_tots.tracks],
                     genre.played_tracks, "%6.2f" % [genre.played_tracks*100.0/@db_tots.played],
                     genre.played_time.to_day_length, "%6.2f" % [genre.played_time*100.0/@db_tots.tot_ptime] ])
        end
        genre = @genres[0]
        new_row(["Total", genre.tot_tracks, "%6.2f" % [genre.tot_tracks*100.0/@db_tots.tracks],
                 genre.played_tracks, "%6.2f" % [genre.played_tracks*100.0/@db_tots.played],
                 genre.played_time.to_day_length, "%6.2f" % [genre.played_time*100.0/@db_tots.tot_ptime] ])
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
#         @f << "</body></html>"
        @f.close
    end

    def db_stats
        GtkUI.load_window(GtkIDs::DLG_STATS)
        tv = GtkUI[GtkIDs::STATS_TV]

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
            iter[0] = iter.path.to_s.to_i < 3
            iter[1] = key
        }

        if GtkUI[GtkIDs::DLG_STATS].run != Gtk::Dialog::RESPONSE_OK
            GtkUI[GtkIDs::DLG_STATS].destroy
            return
        end

        @html = IO.read('./stats.template.html')
        init_globals(Cfg.rsrc_dir+"dbstats.html", "CDsDB Statistics")
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

        @html.sub!(/___TITLE___/, 'CDsDB Statistics')
        @html.sub!(/___TABLES___/, @tables)
        IO.write(Cfg.rsrc_dir+'dbstats.html', @html)
#         cleanup

        GtkUI[GtkIDs::DLG_STATS].destroy
    end

end