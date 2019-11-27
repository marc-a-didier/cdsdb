
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


    TV_ITEMS = {'Played tracks by hosts' => [false, :tracks_by_hosts],
                'Rated and tagged tracks' => [false, :rating_tags_stats],
                'Played tracks by genre' => [false, :played_by_genre],

                'Records by artists' => [false,  :records_by_artists],
                'Records by genres' => [true, :records_by_genre],

                'Last 1000 played' => [false, :gen_play_history],

                'Charts by genre' => [false, :top_genres],
                'Charts by genre & artists' => [false, :charts_by_artists],
                'Charts by genre & records' => [false, :charts_by_records],
                'Charts by genre & tracks' => [false, :charts_by_tracks],

                'List of rated tracks' => [false, :top_rated_tracks] }

    # SQL filter for sorting classic/baroque/gregorian out of selection
    NO_CBG = 'records.rgenre NOT IN (1, 28, 41)'

    class GTable

        attr_reader :title

        def initialize(title = '')
            @columns = ''
            @rows = ''
            @formatters = ''
            @title = title
            @id = 0
        end

        def add_columns(columns)
            columns.each do |col|
                @columns << "data.addColumn('#{col[0]}', '#{col[1]}');\n"
            end
            return self
        end

        def add_row(row)
            @rows << "data.addRow(#{row.to_s});\n"
            return self
        end

        def set_bar_format(columns)
            columns.each do |column|
                @id += 1
                @formatters << "var formatter#{@id} = new google.visualization.BarFormat({width: 120,max: 100});\n"
                @formatters << "formatter#{@id}.format(data, #{column});\n"
            end
        end

        def sub_data(template, id)
            return template.sub(/___DATA_COLUMNS___/, @columns).sub(/___DATA_ROWS___/, @rows).
                            sub(/___FORMATTERS___/, @formatters).sub(/@@id@@/, id.to_s)
        end
    end

    class GTables

        def initialize
            @tables = []
        end

        def add(title = '')
            @tables << GTable.new(title)
            return @tables.last
        end

        def render
            template = IO.read('../scripts/table_chart.template.html')
            File.open(Cfg.rsrc_dir+'dbstats.html', 'w') do |f|
                f.write("<!DOCTYPE html>\n<head>\n<meta charset='UTF-8'>\n")
                header = ''
                @tables.each.with_index(1) { |table, id| header << table.sub_data(template, id) }
                header += "</head>\n"

                body = "<body>\n"+"<h2>CDsDB stats generated #{Time.now}</h2><br />\n"
                @tables.each.with_index(1) { |table, id| body << "<hr><h3>#{table.title}</h3><br/>\n" + "<div id='table_chart_#{id}_div'></div>\n" }
                body << "\n</body>"

                f.write(header, body)
            end
        end
    end

    def initialize
        @tables = GTables.new
    end

    def get_count(stbl)
        return DBIntf.get_first_value("SELECT COUNT(r#{stbl}) FROM #{stbl}s;")
    end

    def init_globals
        # @genres is an array of GenreStruct. @genres[0] is the global total of all genres
        @db_tots = DBTotals.new
        @media = Hash.new

        # Initialize db totals
        %w[artist record segment track].each_with_index { |table, i| @db_tots[i] = get_count(table) }
        @db_tots.ptime = DBIntf.get_first_value('SELECT SUM(iplaytime) FROM records;').to_i
        @db_tots.played = DBIntf.get_first_value('SELECT COUNT(rtrack) FROM logtracks;')
        @db_tots.tot_ptime = DBIntf.get_first_value('SELECT SUM(iplayed*iplaytime) FROM tracks WHERE iplayed > 0;')

        # Initialize totals by genres
        @genres = Array.new(1, GenreStruct.new.init)
        DBIntf.execute('SELECT * FROM genres WHERE rgenre<>0 ORDER BY sname;') { |row| @genres << GenreStruct.new(row[0], row[1]).init }
        @genres.each { |genre| init_table(genre) }
        @genres.delete_if { |genre| genre.tot_tracks == 0 } # Remove genres with no tracks
    end

    def db_general_infos
        tot_played = DBIntf.get_first_value('SELECT COUNT(rtrack) FROM logtracks')
        never_played = DBIntf.get_first_value('SELECT COUNT(rtrack) FROM tracks WHERE iplayed=0')
        dist_played = DBIntf.get_first_value('SELECT COUNT(DISTINCT(rtrack)) FROM logtracks')

        @tables.add('General Info').
                add_columns([ [:string, 'Type'], [:number, 'Count'], [:string, ''] ]).
                add_row(['Total number of artists', @db_tots.artists, '']).
                add_row(['Total number of records', @db_tots.records, "Duration: #{@db_tots.ptime.to_day_length}"]).
                add_row(['Total number of segments', @db_tots.segments, '']).
                add_row(['Total number of tracks', @db_tots.tracks, '']).
                add_row(['Never played tracks', never_played, '']).
                add_row(['Distinct played tracks', dist_played, '']).
                add_row(['Played tracks total', tot_played, "Duration: #{@db_tots.tot_ptime.to_day_length}"])

        table = @tables.add('Records by media type').add_columns([ [:string, 'Medium'], [:number, 'Records'],
                                                                   [:number, '%'], [:string, 'Duration'] ])
        DBIntf.execute('SELECT * FROM medias;') do |mediatype|
            DBIntf.execute("SELECT COUNT(rrecord), SUM(iplaytime) FROM records WHERE rmedia=#{mediatype[0]};") do |row|
                @media[mediatype[1]] = [row[0], row[1]]
                table.add_row([mediatype[1], row[0], row[0]*100.0/@db_tots.records, row[1].to_i.to_day_length])
            end
        end
#         table.add_formatter("table.setColumnProperty(2, 'style', 'text-align:right');")
        table.set_bar_format([2])
    end

    def init_table(genre)
        if genre.ref == 0
            row = DBIntf.get_first_row('SELECT COUNT(rtrack), SUM(iplaytime) FROM tracks;')
            genre.tot_tracks = row[0].to_i
            genre.tot_time = row[1].to_i
            row = DBIntf.get_first_row('SELECT SUM(iplayed), SUM(iplayed*iplaytime) FROM tracks WHERE iplayed > 0;')
            genre.played_tracks = row[0].to_i
            genre.played_time = row[1].to_i
            row = DBIntf.get_first_row("SELECT COUNT(rrecord), SUM(iplaytime) FROM records") # WHERE rmedia <> #{Audio::MEDIA_FILE}")
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
                   WHERE rgenre=#{genre.ref};" # AND rmedia <> #{Audio::MEDIA_FILE};"
            row = DBIntf.get_first_row(sql)
            genre.tot_recs = row[0].to_i
            genre.tot_rectime = row[1].to_i
        end
    end

    def ripped_stats(genre)
        audio_link = Audio::Link.new
#         DBIntf.execute("SELECT rrecord FROM records WHERE rgenre=#{genre.ref} AND rmedia<>#{Audio::MEDIA_FILE}") do |record|
        DBIntf.execute("SELECT rrecord FROM records WHERE rgenre=#{genre.ref}") do |record|
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
        table = @tables.add('Ripped records').add_columns([
                            [:string, 'Genre'], [:number, 'Ripped'], [:number, 'Available'],
                            [:string, 'Ripped duration'], [:string, 'Available duration'] ])
        @genres.each do |genre|
            next if genre.ref == 0
            table.add_row([genre.name, genre.ripped, genre.tot_recs,
                           genre.riptime.to_day_length, genre.tot_rectime.to_day_length])
        end
        genre = @genres[0]
        table.add_row(['Total', genre.ripped, genre.tot_recs,
                       genre.riptime.to_day_length, genre.tot_rectime.to_day_length])
    end

    def records_by_artists
        sql = 'SELECT COUNT(records.rrecord) AS nrecs, SUM(records.iplaytime), artists.sname FROM artists
               INNER JOIN records ON artists.rartist=records.rartist
               GROUP BY artists.rartist ORDER BY nrecs DESC;'
        table = @tables.add('Records by artists').add_columns([ [:string, 'Artist'], [:number, 'Records'], [:string, 'Duration'] ])
        DBIntf.execute(sql) do |row|
            table.add_row([row[2], row[0], row[1].to_i.to_day_length])
        end
    end

    def top_genres
        sql = 'SELECT SUM(iplayed) AS totplayed, genres.sname, COUNT(iplayed) FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN genres ON records.rgenre=genres.rgenre
               WHERE iplayed > 0 GROUP BY records.rgenre ORDER BY totplayed DESC;'
        cols = []
        table = @tables.add('Music Style Top Chart').add_columns([
                            [:number, 'Play count'], [:string, 'Genre'], [:number, 'Played'],
                            [:number, 'Available'], [:number, '% Played'] ])
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            genre = @genres.detect { |g| g.to_a.index(row[1]) }
            cols = [row[0], row[1]]
            cols += [row[2], genre.tot_tracks, row[2].to_f/genre.tot_tracks.to_f*100.0] if genre
            table.add_row(cols)
        end
        table.set_bar_format([4])
    end

    def top_artists(genre)
        sql = 'SELECT SUM(iplayed) AS totplayed, artists.sname FROM tracks
               LEFT OUTER JOIN segments ON tracks.rsegment=segments.rsegment
               LEFT OUTER JOIN artists ON artists.rartist=segments.rartist
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord '

        if genre.ref == 0
            table = @tables.add('All Styles Artists Top Chart')
            sql += 'WHERE iplayed > 0 GROUP BY artists.rartist ORDER BY totplayed DESC'
        else
            table = @tables.add("#{genre.name} Artists Top Chart")
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre.ref} GROUP BY artists.rartist ORDER BY totplayed DESC"
        end
        sql += ' LIMIT 1000;'
        table.add_columns([ [:number, 'Play count'], [:string, 'Artist'] ])
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            table.add_row([row[0], row[1]])
        end
    end

    def top_records(genre)
        sql = 'SELECT SUM(iplayed) AS totplayed, records.stitle, artists.sname FROM tracks
               LEFT OUTER JOIN records ON tracks.rrecord=records.rrecord
               LEFT OUTER JOIN artists ON artists.rartist=records.rartist '

        if genre.ref == 0
            table = @tables.add('All Styles Records Top Chart')
            sql += 'WHERE iplayed > 0 GROUP BY records.rrecord ORDER BY totplayed DESC'
        else
            table = @tables.add("#{genre.name} Records Top Chart")
            sql += "WHERE iplayed > 0 AND records.rgenre=#{genre.ref} GROUP BY records.rrecord ORDER BY totplayed DESC"
        end
        sql += ' LIMIT 1000;'
        table.add_columns([ [:number, 'Play count'], [:string, 'Record'], [:string, 'Artist'] ])
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            table.add_row([row[0], row[1], row[2]])
        end
    end

    def top_tracks(genre)
        if genre.ref == 0
            table = @tables.add('All Styles Tracks Top Chart')
            sql = "SELECT rtrack, stitle, iplayed FROM tracks WHERE iplayed > 0 ORDER BY iplayed DESC;"
        else
            table = @tables.add("#{genre.name} Tracks Top Chart")
            sql = "SELECT tracks.rtrack, tracks.stitle, tracks.iplayed FROM tracks
                   INNER JOIN segments ON segments.rsegment=tracks.rsegment
                   INNER JOIN records ON records.rrecord=segments.rrecord
                   WHERE iplayed > 0 AND records.rgenre=#{genre.ref} ORDER BY iplayed DESC;"
        end
        table.add_columns([ [:number, 'Play count'], [:string, 'Track'],
                            [:string, 'Artist'], [:string, 'Record'], [:string, 'Segment'] ])
        audio_link = Audio::Link.new
        DBIntf.execute(sql) do |row|
            Gtk.main_iteration while Gtk.events_pending?
            audio_link.reset.set_track_ref(row[0].to_i)
            table.add_row([row[2], row[1], audio_link.segment_artist.sname, audio_link.record.stitle, audio_link.segment.stitle])
        end
    end

    def top_rated_tracks
        audio_link = Audio::Link.new
        table = @tables.add('Most rated tracks').add_columns([ [:string, 'Rating'], [:string, 'Track'], [:string, 'Artist'],
                                                               [:string, 'Record'], [:string, 'Segment'] ])
        DBIntf.execute("SELECT rtrack, stitle, irating FROM tracks WHERE irating > 0 ORDER BY irating DESC;") do |row|
            Gtk.main_iteration while Gtk.events_pending?
            audio_link.reset.set_track_ref(row[0])
            table.add_row([Qualifiers::RATINGS[row[2]], row[1], audio_link.segment_artist.sname,
                           audio_link.record.stitle, audio_link.segment.stitle])
        end
    end

    def gen_play_history
        limit = 1000
        audio_link = Audio::Link.new
        table = @tables.add("Last #{limit} played tracks").add_columns([
                            [:string, 'When'], [:string, 'Where'], [:string, 'Track'],
                            [:string, 'Artist'], [:string, 'Record'], [:string, 'Segment'] ])
        sql = %Q{SELECT logtracks.rtrack, logtracks.idateplayed, hosts.sname, records.rrecord, records.irecsymlink FROM logtracks
                 INNER JOIN hosts ON hosts.rhost=logtracks.rhost
                 INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                 INNER JOIN segments ON tracks.rsegment=segments.rsegment
                 INNER JOIN records ON records.rrecord=segments.rrecord
                 INNER JOIN artists ON artists.rartist=records.rartist
                 WHERE tracks.iplayed > 0
                 ORDER BY logtracks.idateplayed DESC LIMIT #{limit};}
        DBIntf.execute(sql) do |row|
            audio_link.reset.set_track_ref(row[0])
            table.add_row([Time.at(row[1].to_i).to_s, row[2], audio_link.track.stitle,
                           audio_link.segment_artist.sname, audio_link.record.stitle, audio_link.segment.stitle])
        end
    end

    def tracks_by_hosts
        tot_played = DBIntf.get_first_value('SELECT COUNT(rtrack) FROM logtracks')

        table = @tables.add('Played tracks by hosts').add_columns([ [:string, 'Host'], [:number, 'Count'], [:number, '%'] ])
        DBIntf.execute('SELECT * FROM hosts') do |host|
            host_played = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks WHERE rhost=#{host[0]}")
            table.add_row([host[1], host_played, host_played*100.0/tot_played])
        end
        table.set_bar_format([2])
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
            @tables.add(title+' tracks without Classical/Baroque').add_columns([
                       [:string, first_col], [:number, '# of tracks'], [:number, 'Percentage'],
                       [:number, 'Played'], [:number, 'Percentage'],
                       [:string, 'Played time'], [:number, 'Percentage'] ])
        end

        def gen_row(table, title, data_row, tot_row)
            table.add_row([title,
                           data_row[0], data_row[0]*100.0/tot_row[0],
                           data_row[1], data_row[1]*100.0/tot_row[1],
                           data_row[2].to_day_length, data_row[2]*100.0/tot_row[2]])
        end

        # Total tracks, played tracks and total playtime without classic.
        # Valid for both rating and tags.
        tot_row = exec_filtered_sql('')

        #
        # Ratings
        #

        tot_rated_row = exec_filtered_sql('tracks.irating<>0')
        tot_unrated_row = exec_filtered_sql('tracks.irating=0')

        table = gen_table('Rated', 'Rating')
        (1..6).each do |index|
            data_row = exec_filtered_sql("tracks.irating=#{index}")

            gen_row(table, Qualifiers::RATINGS[index], data_row, tot_row)
        end
        gen_row(table, 'Qualified', tot_rated_row, tot_row)
        gen_row(table, 'Unqualified', tot_unrated_row, tot_row)

        3.times { |i| tot_rated_row[i] += tot_unrated_row[i] }
        gen_row(table, 'Tracks', tot_rated_row, tot_row)

        table.set_bar_format([2, 4, 6])

        #
        # Tags
        #
        tot_tagged_row = exec_filtered_sql('tracks.itags<>0')
        tot_untagged_row = exec_filtered_sql('tracks.itags=0')

        table = gen_table('Tagged', 'Tag')
        Qualifiers::TAGS.each_with_index do |tag, index|
            data_row = exec_filtered_sql("(tracks.itags & #{1 << index}) <> 0")

            gen_row(table, tag, data_row, tot_row)
        end
        gen_row(table, 'Tagged', tot_tagged_row, tot_row)
        gen_row(table, 'Untagged', tot_untagged_row, tot_row)

        3.times { |i| tot_tagged_row[i] += tot_untagged_row[i] }
        gen_row(table, 'Tracks', tot_tagged_row, tot_row)

        table.set_bar_format([2, 4, 6])
    end

    def played_by_genre
        table = @tables.add('Played tracks by genre').add_columns([
                            [:string, 'Genre'], [:number, '# of tracks'], [:number, 'Percentage'],
                            [:number, 'Played'], [:number, 'Percentage'], [:string, 'Played time'],
                            [:number, 'Percentage'] ])

        @genres.each_with_index do |genre, i|
            next if i == 0
            table.add_row([genre.name, genre.tot_tracks, genre.tot_tracks*100.0/@db_tots.tracks,
                           genre.played_tracks, genre.played_tracks*100.0/@db_tots.played,
                           genre.played_time.to_day_length, genre.played_time*100.0/@db_tots.tot_ptime ])
        end
        genre = @genres[0]
        table.add_row(['Total', genre.tot_tracks, genre.tot_tracks*100.0/@db_tots.tracks,
                 genre.played_tracks, genre.played_tracks*100.0/@db_tots.played,
                 genre.played_time.to_day_length, genre.played_time*100.0/@db_tots.tot_ptime ])

        table.set_bar_format([2, 4, 6])
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

    def db_stats
        GtkUI.load_window(GtkIDs::DLG_STATS)
        tv = GtkUI[GtkIDs::STATS_TV]

        tv.model = Gtk::ListStore.new(TrueClass, String)

        arenderer = Gtk::CellRendererToggle.new
        arenderer.activatable = true
        arenderer.signal_connect(:toggled) do |w, path|
            iter = tv.model.get_iter(path)
            iter[0] = !iter[0] if (iter)
        end
        srenderer = Gtk::CellRendererText.new()

        tv.append_column(Gtk::TreeViewColumn.new('Select', arenderer, :active => 0))
        tv.append_column(Gtk::TreeViewColumn.new('Stat', srenderer, :text => 1))
        TV_ITEMS.each do |key, value|
            iter = tv.model.append
            iter[0] = iter.path.to_s.to_i < 3
            iter[1] = key
        end

        if GtkUI[GtkIDs::DLG_STATS].run != Gtk::Dialog::RESPONSE_OK
            GtkUI[GtkIDs::DLG_STATS].destroy
            return
        end

        init_globals
        db_general_infos

        # Check to see if a selection needs the ripped records data
        tv.model.each do |model, path, iter|
            if iter[0] && TV_ITEMS[iter[1]][0]
                @genres.each { |genre| ripped_stats(genre) if genre[0] != 0 }
                break
            end
        end

        tv.model.each do |model, path, iter|
            self.send(TV_ITEMS[iter[1]][1]) if iter[0]
        end

        @tables.render

        GtkUI[GtkIDs::DLG_STATS].destroy
    end

end
