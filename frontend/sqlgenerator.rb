
#
# Generate the appropriate insert statements to add a new cd or audio file to the database.
#
#

class SQLGenerator

    RESULT_SQL_FILE = CFG.rsrc_dir+"cdssql.txt"

    HA_ARTIST  = 0

    HS_SEGMENT = 0
    HS_ARTIST  = 1
    HS_STTIME  = 2
    HS_ORDER   = 3

    DI_ORDER   = 0
    DI_TRACK   = 1
    DI_SEGMENT = 2
    DI_ARTIST  = 3
    DI_LENGTH  = 4

    def init(disc)
        @disc = disc

        @comments = ""

        @is_compile = @disc.tracks.find_all { |track| track.artist != @disc.artist }.size > 0

        @discinfo = []
        @disc.tracks.each_with_index do |track, i|
            @discinfo << [i+1, track.title, track.segment, format_artist(track.artist), track.length]
        end

        @main_artist = format_artist(@disc.artist)

        @is_segmented = false
        @seg_title = ""
        @segments = []
        @disc.tracks.each { |track| @segments << track.segment }
        segs = @segments.uniq
        if segs.size == 1
            @seg_title = segs[0] unless segs[0] == @disc.title
        else
            @is_segmented = true
        end
        @tracks = Array.new
        @hartists = Hash.new # name => rartist
        @hsegments = Hash.new # segment => rsegment, rartist, sttime
        seg_counter = 0
        @segments.each_with_index { |segment, i|
            unless @hsegments.include?(@discinfo[i][DI_ARTIST]+segment)
                seg_counter += 1
                @hsegments[@discinfo[i][DI_ARTIST]+segment] = [0, i, 0, seg_counter]
            end
        }

        @disc.tracks.size.times do |i|
            if @hsegments.include?(@discinfo[i][DI_ARTIST]+@segments[i])
                @hsegments[@discinfo[i][DI_ARTIST]+@segments[i]][HS_STTIME] += @discinfo[i][DI_LENGTH]
            end
            @tracks[i] = []
            @tracks[i][0] = @disc.tracks[i].title
            @tracks[i][1] = '' # Comments
        end

        if @is_compile
            @disc.tracks.each { |track| @hartists[format_artist(track.artist)] = 0 }
        else
            @hartists[@main_artist] = 0
        end
        @main_rartist = 0
        @recordid = 0
        @rgenre = 1

        return self
    end

    def format_artist(artist)
        return "Unknown" if artist.empty?

        prefix = artist[0..3].downcase
        if prefix == "the " || prefix == "die " || prefix == "les "
            return artist[4..-1]+", "+artist[0..2]
        else
            return artist
        end
    end

    def check_genre
        row = CDSDB.get_first_row("SELECT * FROM genres WHERE LOWER(sname)=LOWER(#{@disc.genre.to_sql});")
        if row.nil?
            @rgenre = DBUtils::get_last_id("genre")+1
            @sqlf << "INSERT INTO genres VALUES (#{@rgenre}, #{@disc.genre.to_sql});\n"
        else
            @rgenre = row[0]
        end
    end

    def insert_artists
        rartist = DBUtils.get_last_id("artist")
        @hartists.each_key do |key|
            row = CDSDB.get_first_row("SELECT * FROM artists WHERE LOWER(sname)=LOWER(#{key.to_sql})")
            if row.nil?
                rartist += 1
                @sqlf << "INSERT INTO artists VALUES (#{rartist}, #{key.to_sql}, '', 0, '');\n"
                @hartists[key] = rartist
            else
                @hartists[key] = row[0]
            end
        end
        @main_rartist = @hartists[@main_artist] if !@is_compile
    end

    def insert_record
        row = nil #CDSDB.get_first_row("SELECT * FROM records WHERE LOWER(stitle)=LOWER(#{@disc.title.to_sql}) AND rartist=#{@main_rartist}")
        if row.nil?
            issegd = @is_segmented ? 1 : 0
            @recordid = DBUtils::get_last_id("record")+1
            @sqlf << "INSERT INTO records (rrecord, icddbid, rartist, stitle, iyear, rgenre, rmedia, iplaytime, mnotes, idateadded, iissegmented) " \
                        "VALUES (#{@recordid}, #{@disc.cddbid}, #{@main_rartist}, " \
                                "#{@disc.title.to_sql}, #{@disc.year}, #{@rgenre}, " \
                                "#{@disc.medium}, #{@disc.length}, #{@comments.to_sql}, #{Time.now.to_i}, #{issegd});\n"
        else
            @recordid = row[0]
        end
    end

    def insert_segments
        rsegment = DBUtils::get_last_id("segment")
        @hsegments.each do |key, value|
            row = nil #CDSDB.get_first_row("SELECT * FROM segments WHERE LOWER(stitle)=LOWER(#{@discinfo[value[1]][2].to_sql}) AND rartist=#{@hartists[@discinfo[value[1]][3]]} AND rrecord=#{@recordid}")
            if row.nil?
                rsegment += 1
                seg_title = @is_segmented ? @discinfo[value[HS_ARTIST]][DI_SEGMENT] : @seg_title
                @sqlf << "INSERT INTO segments (rsegment, rrecord, rartist, iorder, stitle, iplaytime) " \
                            "VALUES (#{rsegment}, #{@recordid}, " \
                            "#{@hartists[@discinfo[value[HS_ARTIST]][DI_ARTIST]]}, #{value[HS_ORDER]}, " \
                            "#{seg_title.to_sql}, #{value[HS_STTIME]});\n"
                value[HS_SEGMENT] = rsegment
            else
                value[HS_SEGMENT] = row[0]
            end
        end
    end

    def insert_tracks
        seg_order = 0
        rtrack = DBUtils::get_last_id("track")
        @tracks.each_with_index do |track, i|
            if @is_segmented
                seg_order = (i == 0 || @segments[i] != @segments[i-1]) ? 1 : seg_order+1
            end
            hsegkey = @discinfo[i][DI_ARTIST]+@discinfo[i][DI_SEGMENT]
            row = nil #CDSDB.get_first_row("SELECT * FROM tracks WHERE LOWER(stitle)=LOWER(#{@tracks[i][0].to_sql}) AND rsegment=#{@hsegments[hsegkey][HS_SEGMENT]}")
            if row.nil?
                rtrack += 1
                @sqlf << "INSERT INTO tracks (rtrack, rsegment, rrecord, iorder, iplaytime, stitle, mnotes, isegorder) " \
                           "VALUES (#{rtrack}, #{@hsegments[hsegkey][HS_SEGMENT]}, #{@recordid}, " \
                           "#{i+1}, #{@discinfo[i][DI_LENGTH]}, " \
                           "#{track[0].to_sql}, #{track[1].to_sql}, #{seg_order});\n"
            end
        end
    end

    def generate_inserts
        @sqlf = File.new(RESULT_SQL_FILE, "w")
        check_genre
        insert_artists
        insert_record
        insert_segments
        insert_tracks
        @sqlf.close
    end

    def process_record(disc)
        init(disc)
        generate_inserts
    end
end
