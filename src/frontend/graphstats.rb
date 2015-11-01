
class DatesHandler

    END_OF_DAY_OFFSET = 23*60*60+59*60+59

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
        t = Time.at(next_offset.to_time.to_i-1)
        return Time.new(t.year, t.month, t.day, 23, 59, 59).to_i
        #next_offset.to_time.to_i #-1 #+END_OF_DAY_OFFSET).to_i
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
end

class GraphStats

    def initialize
        @charts = []
    end

    def new_chart(type, data_titles, data_rows, options)
        html = IO.read("../scripts/#{type}_chart.template.html")

        html.sub!(/___DATA_TITLES___/, data_titles)
        html.sub!(/___DATA_ROWS___/, data_rows)
        html.sub!(/___CHART_OPTS___/, options)

        @charts << html
    end

    def render_charts
        File.open(Cfg.rsrc_dir+'dbstats.html', 'w') do |f|
            f.write('<!DOCTYPE html><head><meta charset="UTF-8">')
            body = "</head>\n<body>\n"
            @charts.each_with_index do |chart, i|
                chart.sub!(/@@id@@/, (i+1).to_s)
                id = chart.match(/getElementById\('(.+)'\)/).captures.first
                body << "<div id='#{id}'></div>\n"
                f.write(chart)
            end
            body << "</body>"
            f.write(body)
        end
    end

    def genres_played_line
        genres = {}
        DBIntf.execute("SELECT sname FROM genres WHERE rgenre<>0;") { |row| genres[row[0]] = 0 }
        dh = DatesHandler.new(Time.new(2014, 12, 1).to_s, :day)
        data = []
        dh.range.each do |i|
            start_date = Time.new(2014, 12, i).to_i
            end_date = Time.new(2014, 12, i, 23, 59, 59).to_i
            sql = %{
                SELECT genres.sname, COUNT(records.rgenre) FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                    INNER JOIN records ON tracks.rrecord=records.rrecord
                    INNER JOIN genres ON records.rgenre=genres.rgenre
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
                GROUP BY records.rgenre;
            }
            DBIntf.execute(sql) { |row| genres[row[0]] = row[1] }
            data << [Time.at(dh.start_date).strftime('%b %-d %Y')]
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
                  data.map { |row| row.to_s }.join(",\n"),
                  "title: 'Daily play count by genre', hAxis: { title: 'Day'}, vAxis: { title: 'Play count' }")
    end

    def artists_col_chart
        dh = DatesHandler.new(Time.new(2015, 10, 1).to_s, :month)
        sql = %{
            SELECT artists.sname, COUNT(segments.rartist) AS artcount FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                INNER JOIN segments ON tracks.rsegment=segments.rsegment
                INNER JOIN artists ON segments.rartist=artists.rartist
            WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date}
            GROUP BY segments.rartist ORDER BY artcount DESC LIMIT 50;
        }

        new_chart(:column,
                  "['Artist', 'Play count']",
                  DBIntf.execute(sql).map { |entry| entry.to_s }.join(",\n"),
                  "title: '50 most played artists from #{dh.start_date.to_std_date} to #{dh.end_date.to_std_date}'")
    end

    def tags_col_chart
        start_date = Time.new(2014, 1, 1).to_i
        end_date = Time.new(2014, 12, 31, 23, 59, 59).to_i

        sql = %{
            SELECT tracks.itags FROM logtracks
                INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
            WHERE logtracks.idateplayed >= #{start_date} AND logtracks.idateplayed <= #{end_date} AND
                  tracks.itags<>0;
        }

        tags = Array.new(Qualifiers::TAGS.size).fill { |i| [Qualifiers::TAGS[i], 0] }
        DBIntf.execute(sql) do |row|
            Qualifiers::TAGS.size.times { |i| tags[i][1] += 1 if row[0] & (1 << i) != 0 }
        end

        @html.sub!(/___CC_ROWS___/, tags.map { |tag| tag.to_s }.join(",\n"))
    end

    def ratings_line_chart
        ratings = []
        dh = DatesHandler.new(Time.new(2014).to_s, :month)
        dh.range.each do
            sql = %{
                SELECT tracks.irating FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date};
            }

            ratings << Array.new(Qualifiers::RATINGS.size+1, 0)
            ratings.last[0] = Time.at(dh.start_date).strftime('%b %Y')
            DBIntf.execute(sql) do |row|
                Qualifiers::RATINGS.size.times { |i| ratings.last[row[0]+1] += 1 }
            end
            dh.next_date
        end
        new_chart(:line,
                  "['Ratings', "+Qualifiers::RATINGS.map { |rating| '"'+rating+'"' }.join(',')+']',
                  ratings.map { |rating| rating.to_s }.join(",\n"),
                  "title: 'Monthly play count by rating', hAxis: { title: 'Periods'}, vAxis: { title: 'Play count' }")
    end

    def tags_line_chart
        tags = []
        dh = DatesHandler.new(Time.new(2014).to_s, :month)
        dh.range.each do
            sql = %{
                SELECT tracks.itags FROM logtracks
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                WHERE logtracks.idateplayed >= #{dh.start_date} AND logtracks.idateplayed <= #{dh.end_date} AND
                    tracks.itags<>0;
            }

            tags << Array.new(Qualifiers::TAGS.size+1, 0)
            tags.last[0] = Time.at(dh.start_date).strftime('%b %Y')
            DBIntf.execute(sql) do |row|
                Qualifiers::TAGS.size.times { |i| tags.last[i+1] += 1 if row[0] & (1 << i) != 0 }
            end
            dh.next_date
        end
        new_chart(:line,
                  "['Tags', "+Qualifiers::TAGS.map { |tag| '"'+tag+'"' }.join(',')+']',
                  tags.map { |tag| tag.to_s }.join(",\n"),
                  "title: 'Monthly play count by tag', hAxis: { title: 'Periods'}, vAxis: { title: 'Play count' }")
        ratings_line_chart
        genres_played_line
        artists_col_chart
        render_charts
    end
end
