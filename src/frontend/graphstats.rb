
class DatesHandler

    def initialize(from_date, increment)
        @curr_date = DateTime.parse(from_date)
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
            when :day   then (1..Date.new(@curr_date.year, @curr_date.month, -1).day)
            when :month then (1..12)
            when :year  then (2010..2015)
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
            body = "</head>\n<body>\n"
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

    def self.genres_chart(start_date, period, type)
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
        new_chart(type,
                  genres.keys.unshift('Genre').to_s,
                  data.map { |row| row.to_s }.join(",\n"),
                  "title: '#{dh.period_label} play count by genre', vAxis: { title: 'Play count' }")
    end

#     def self.artists_col_chart
#         dh = DatesHandler.new(Time.new(2014, 1, 1).to_s, :year)
#         sql = %{
#             SELECT artists.sname, COUNT(segments.rartist) AS artcount FROM logtracks
#                 INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
#                 INNER JOIN segments ON tracks.rsegment=segments.rsegment
#                 INNER JOIN artists ON segments.rartist=artists.rartist
#             WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
#             GROUP BY segments.rartist ORDER BY artcount DESC LIMIT 50;
#         }
#
#         new_chart(:column,
#                   "['Artist', 'Play count']",
#                   DBIntf.execute(sql).map { |entry| entry.to_s }.join(",\n"),
#                   "title: '50 most played artists from #{dh.start_date.to_std_date} to #{dh.end_date.to_std_date}'")
#     end

    def self.artists_col_chart
        sql = %{
            SELECT artists.rartist, artists.sname, COUNT(segments.rartist) AS artcount FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN segments ON tracks.rsegment=segments.rsegment
                INNER JOIN artists ON segments.rartist=artists.rartist
            GROUP BY segments.rartist ORDER BY artcount DESC LIMIT 20;
        }
        artists = DBIntf.execute(sql)

        data = Array.new(artists.size).fill { |i| [artists[i][1]] }
        dh = DatesHandler.new(Time.new(2010, 1, 1).to_s, :year)
        dh.range.each do
            artists.each_with_index do |artist, i|
                sql = %{
                    SELECT COUNT(segments.rartist) FROM logtracks
                        INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                        INNER JOIN segments ON tracks.rsegment=segments.rsegment
                    WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date} AND
                          segments.rartist=#{artist[0]};
                }
                data[i] << DBIntf.get_first_value(sql)
            end
            dh.next_date
        end

        new_chart(:column,
                  dh.range.to_a.map { |y| y.to_s }.unshift('Artist').to_s,
                  data.map { |entry| entry.to_s }.join(",\n"),
                  "title: '20 most played artists'")
    end

    def self.tags_col_chart(start_date, period, type)
        yix = 1
        data = Array.new(Qualifiers::TAGS.size).fill { |i| [Qualifiers::TAGS[i]] }
        dh = DatesHandler.new(start_date, period)
        dh.range.each do
            sql = %{
                SELECT tracks.itags FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date} AND
                    tracks.itags<>0;
            }

            data.each { |tag| tag << 0 }
            DBIntf.execute(sql) do |row|
                Qualifiers::TAGS.size.times { |i| data[i][yix] += 1 if row[0] & (1 << i) != 0 }
            end
            yix += 1
            dh.next_date
        end

        new_chart(type,
                  dh.range.to_a.map { |y| y.to_s }.unshift('Tags').to_s,
                  data.map { |entry| entry.to_s }.join(",\n"),
                  "title: 'Play count by tags'")
    end

    def self.ratings_chart(start_date, period, type)
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
        new_chart(type,
                  "['Ratings', "+Qualifiers::RATINGS.map { |rating| '"'+rating+'"' }.join(',')+']',
                  ratings.map { |rating| rating.to_s }.join(",\n"),
                  "title: '#{dh.period_label} play count by rating', vAxis: { title: 'Play count' }")
    end

    def self.played_tracks(start_date, period, type)
        data = []
        dh = DatesHandler.new(start_date, period)
        dh.range.each do
            sql = %{
                SELECT COUNT(rtrack) FROM logtracks
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date};
            }
            data << [dh.x_axis_label, DBIntf.get_first_value(sql)]
            dh.next_date
        end
        new_chart(type,
                  "['Year', 'Play count']",
                  data.map { |entry| entry.to_s }.join(",\n"),
                  "title: '#{dh.period_label} played tracks'")
    end

    def self.tags_chart(start_date, period, type)
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
        new_chart(type,
                  "['Tags', "+Qualifiers::TAGS.map { |tag| '"'+tag+'"' }.join(',')+']',
                  tags.map { |tag| tag.to_s }.join(",\n"),
                  "title: '#{dh.period_label} play count by tag', vAxis: { title: 'Play count' }")
    end

    def self.draw_charts
        charts = []
        charts << played_tracks(Time.new(2015, 10, 4).to_s, :day, :line)
        charts << tags_chart(Time.new(2015, 10, 4).to_s, :day, :line)
        charts << ratings_chart(Time.new(2015, 10, 4).to_s, :day, :line)
        charts << genres_chart(Time.new(2015, 10, 4).to_s, :day, :line)
#         charts << tags_line_chart
#         charts << ratings_line_chart
#         charts << genres_played_line
#         charts << played_tracks
#         charts << tags_col_chart
#         charts << artists_col_chart
#         charts << tags_chart(Time.new(2010).to_s, :year, :column)
#         charts << tags_chart(Time.new(2011).to_s, :month, :line)
#         charts << played_tracks(Time.new(2010).to_s, :year, :column)
#         charts << played_tracks(Time.new(2011).to_s, :month, :column)
        render_charts(charts)
    end
end
