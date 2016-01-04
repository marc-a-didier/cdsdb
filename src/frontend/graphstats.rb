
class DatesHandler

    def initialize(from_date, increment)
        @from_date = from_date
        @curr_date = from_date
        @increment = increment
    end

    def next_offset
        return case @increment
            when :day   then @curr_date + 1
            when :month then @curr_date >> 1
            when :year  then @curr_date.next_year
        end
    end

    def start_date
        return @curr_date.to_time.to_i
    end

    def end_date
        t = next_offset.prev_day
        return Time.new(t.year, t.month, t.day, 23, 59, 59).to_i
    end

    def next_date
        @curr_date = next_offset
    end

    def range
        return case @increment
            when :day   then (1..31) # 30 days back + 1 for today
            when :month then (1..12)
            when :year  then (2010..Date.today.year)
        end
    end

    def x_axis_label
        return case @increment
            when :day   then @curr_date.strftime('%b %-d %Y')
            when :month then @curr_date.strftime('%b %Y')
            when :year  then @curr_date.year.to_s
        end
    end

    def period_label
        return case @increment
            when :day   then "Daily"
            when :month then "Monthly"
            when :year  then "Yearly"
        end
    end

    def start_date_str
        return case @increment
            when :day   then @from_date.strftime("%a %b %-d %Y")
            when :month then @from_date.strftime("%B %Y")
            when :year  then @from_date.strftime("%Y")
        end
    end
end

module GraphStats

    def self.new_chart(type, data_titles, data_rows, options)
        html = IO.read("../scripts/#{type}_chart.template.html")

        html.sub!(/___DATA_TITLES___/, data_titles)
        html.sub!(/___DATA_ROWS___/, data_rows)
        html.sub!(/___CHART_OPTS___/, options)

        return html
    end

    def self.render_charts(charts)
        File.open(Cfg.rsrc_dir+'dbstats.html', 'w') do |f|
            f.write('<!DOCTYPE html><head><meta charset="UTF-8">')
            body = "</head>\n<body>\n".dup
            charts.each_with_index do |chart, i|
                chart.sub!(/@@id@@/, (i+1).to_s)
                id = chart.match(/getElementById\('(.+)'\)/).captures.first
                body << "<div id='#{id}'></div>\n"
                f.write(chart)
            end
            body << "</body>"
            f.write(body)
        end
    end

    def self.played_tracks_evolution(start_date, period)
        data = []
        dh = DatesHandler.new(start_date, period)
        dh.range.each do
            sql = %{
                SELECT logtracks.rhost FROM logtracks
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date};
            }
            rows = DBIntf.execute(sql).flatten
            data << [dh.x_axis_label, rows.size]
            [9, 4, 7].each { |rhost| data.last << rows.count { |rrhost| rhost == rrhost } }
            dh.next_date
        end
        new_chart(:line,
                  "['Year', 'Play count', 'madP9X79', 'jukebox', 'mad.rsd.com']",
                  data.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} played tracks history since #{dh.start_date_str}', curveType: 'function'")
    end

    def self.tags_snapshot(start_date, period)
        tags = Array.new(Qualifiers::TAGS.size).fill { |i| [Qualifiers::TAGS[i], 0] }
        dh = DatesHandler.new(start_date, period)
        sql = %{
            SELECT tracks.itags FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date} AND
                  tracks.itags<>0;
        }
        DBIntf.execute(sql) do |row|
            Qualifiers::TAGS.size.times { |i| tags[i][1] += 1 if row[0] & (1 << i) != 0 }
        end
        new_chart(:column,
                  "['Tags', 'Count']",
                  tags.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count by tag for #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.tags_evolution(start_date, period)
        tags = []
        dh = DatesHandler.new(start_date, period)
        dh.range.each do
            sql = %{
                SELECT tracks.itags FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date} AND
                      tracks.itags<>0;
            }

            tags << Array.new(Qualifiers::TAGS.size+1, 0)
            tags.last[0] = dh.x_axis_label
            DBIntf.execute(sql) do |row|
                Qualifiers::TAGS.size.times { |i| tags.last[i+1] += 1 if row[0] & (1 << i) != 0 }
            end
            dh.next_date
        end
        new_chart(:line,
                  Qualifiers::TAGS.clone.unshift('Tags').to_s,
                  tags.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count history by tag since #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.ratings_snapshot(start_date, period)
        ratings = Array.new(Qualifiers::RATINGS.size).fill { |i| [Qualifiers::RATINGS[i], 0] }
        dh = DatesHandler.new(start_date, period)
        sql = %{
            SELECT tracks.irating FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date};
        }
        DBIntf.execute(sql) do |row|
            ratings[row[0]][1] += 1
        end
        new_chart(:column,
                  "['Rating', 'Count']",
                  ratings.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count by rating for #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.ratings_evolution(start_date, period)
        ratings = []
        dh = DatesHandler.new(start_date, period)
        dh.range.each do
            sql = %{
                SELECT tracks.irating FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date};
            }

            ratings << Array.new(Qualifiers::RATINGS.size+1, 0)
            ratings.last[0] = dh.x_axis_label
            DBIntf.execute(sql) do |row|
                ratings.last[row[0]+1] += 1
            end
            dh.next_date
        end
        new_chart(:line,
                  Qualifiers::RATINGS.clone.unshift('Rating').to_s,
                  ratings.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count history by rating since #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.genres_snapshot(start_date, period)
        genres = {}
        DBIntf.execute("SELECT sname FROM genres WHERE rgenre<>0;") { |row| genres[row[0]] = 0 }
        dh = DatesHandler.new(start_date, period)
        sql = %{
            SELECT genres.sname, COUNT(records.rgenre) FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN records ON tracks.rrecord=records.rrecord
                INNER JOIN genres ON records.rgenre=genres.rgenre
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
            GROUP BY records.rgenre;
        }
        DBIntf.execute(sql) { |row| genres[row[0]] = row[1] }
        genres.delete_if { |k, v| v == 0 }

        new_chart(:column,
                  "['Genres', 'Count']",
                  genres.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count by genre for #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.genres_evolution(start_date, period)
        genres = {}
        DBIntf.execute("SELECT sname FROM genres WHERE rgenre<>0;") { |row| genres[row[0]] = 0 }
        dh = DatesHandler.new(start_date, period)
        data = []
        dh.range.each do |i|
            sql = %{
                SELECT genres.sname, COUNT(records.rgenre) FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                    INNER JOIN records ON tracks.rrecord=records.rrecord
                    INNER JOIN genres ON records.rgenre=genres.rgenre
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
                GROUP BY records.rgenre;
            }
            DBIntf.execute(sql) { |row| genres[row[0]] = row[1] }
            data << [dh.x_axis_label]
            genres.each do |k, v|
                data.last << v
                genres[k] = 0
            end
            dh.next_date
        end

        rm = []
        gi = 1
        genres.each do |k, v|
            s = 0
            data.size.times { |di| s += data[di][gi] }
            rm << [k, gi] if s == 0
            gi += 1
        end
        rm.reverse.each do |rmd|
            data.size.times { |di| data[di].delete_at(rmd[1]) }
            genres.delete(rmd[0])
        end
        new_chart(:line,
                  genres.keys.unshift('Genre').to_s,
                  data.map(&:to_s).join(",\n"),
                  "title: '#{dh.period_label} play count history by genre since #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.artists_snapshot(start_date, period)
        dh = DatesHandler.new(start_date, period)
        sql = %{
            SELECT artists.sname, COUNT(segments.rartist) AS artcount FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN segments ON tracks.rsegment=segments.rsegment
                INNER JOIN artists ON segments.rartist=artists.rartist
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
            GROUP BY segments.rartist ORDER BY artcount DESC LIMIT 20;
        }
        new_chart(:column,
                  "['Artist', 'Count']",
                  DBIntf.execute(sql).map(&:to_s).join(",\n"),
                  "title: '#{dh.start_date_str} 20 most played artists', vAxis: { title: 'Play count' }")
    end

    def self.countries_snapshot(start_date, period)
        dh = DatesHandler.new(start_date, period)
        sql = %{
            SELECT origins.sname, COUNT(artists.rorigin) AS origincount FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN segments ON tracks.rsegment=segments.rsegment
                INNER JOIN artists ON segments.rartist=artists.rartist
                INNER JOIN origins ON artists.rorigin=origins.rorigin
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
            GROUP BY artists.rorigin ORDER BY origincount DESC;
        }
        new_chart(:column,
                  "['Origin', 'Count']",
                  DBIntf.execute(sql).map(&:to_s).join(",\n"),
                  "title: 'Play count by origin for #{dh.start_date_str}', vAxis: { title: 'Play count' }")
    end

    def self.graph_period
        date, period = Dialogs::GraphStatsSelector.run
        if date
            case period
                when :day
                    offset = date - 30
                when :month
                    date = Date.new(date.year, date.month, 1)
                    offset = date << 11
                when :year
                    date = Date.new(date.year, 1, 1)
                    offset = Date.new(2010, 1, 1)
            end

            charts = []
            charts << self.played_tracks_evolution(offset, period)
            charts << self.tags_snapshot(date, period)
            charts << self.tags_evolution(offset, period)
            charts << self.ratings_snapshot(date, period)
            charts << self.ratings_evolution(offset, period)
            charts << self.genres_snapshot(date, period)
            charts << self.genres_evolution(offset, period)
            charts << self.artists_snapshot(date, period)
            charts << self.countries_snapshot(date, period)
            self.render_charts(charts)
        end
    end
end
