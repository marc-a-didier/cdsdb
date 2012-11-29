
#
# Structure returned by check_audio_file
#
AudioFileStatus = Struct.new(:status, :file_name)


class Log

private
    @@log = nil

public
    def Log.instance
        @@log.nil? ? @@log = Logger.new(Cfg::instance.log_file, 100, 2097152) : @@log
    end
end

class String
    def check_plural(quantity)
        return quantity < 2 ? self : self+"s"
    end

    def to_ms_length
        m, s, ms = self.split(/[:,\.]/)
        return m.to_i*60*1000+s.to_i*1000+ms.to_i
    end

    # Not a good idea to introduce a dep on CGI...
    def to_html
        return CGI::escapeHTML(self)
    end

    def to_html_bold
        return "<b>"+self.to_html+"</b>"
    end

    def to_html_italic
        return "<i>"+self.to_html+"</i>"
    end

    def clean_path
        return self.gsub(/\//, "_")
    end

    def make_fat_compliant
        return self.gsub(/[\*|\?|\\|\:|\<|\>|\"|\|]/, "_")
    end

#     def make_fat_compliant!
#         self = make_fat_compliant
#     end

    def to_date_from_utc
        begin
            dt = (Time.at(DateTime.parse(self).to_time)-Time.now.utc_offset).to_i
        rescue ArgumentError
            dt = 0
        end
        return dt
    end

    def to_date
        begin
            dt = Time.at(Date.parse(self).to_time).to_i
        rescue ArgumentError
            dt = 0
        end
        return dt
    end


    # Colorization of ANSI console
    def colorize(color_code)
        "\e[#{color_code}m#{self}\e[0m"
    end

    def black;   colorize(30); end
    def red;     colorize(31); end
    def green;   colorize(32); end
    def brown;   colorize(33); end
    def blue;    colorize(34); end
    def magenta; colorize(35); end
    def cyan;    colorize(36); end
    def gray;    colorize(37); end

    def bold;    colorize(1);  end
    def blink;   colorize(5);  end
    def reverse; colorize(7);  end
end

SEC_MS_LENGTH  = 1000
MIN_MS_LENGTH  = 60*SEC_MS_LENGTH
HOUR_MS_LENGTH = 60*MIN_MS_LENGTH

class Numeric
    def to_ms_length
        m  = self/MIN_MS_LENGTH
        s  = (self-m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        ms = self % SEC_MS_LENGTH
        return sprintf("%02d:%02d.%03d", m, s, ms)
    end

    def to_hr_length
        h = self/HOUR_MS_LENGTH
        m = (self-h*HOUR_MS_LENGTH)/MIN_MS_LENGTH
        s = (self-h*HOUR_MS_LENGTH-m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        return sprintf("%02d:%02d:%02d", h, m, s)
    end

    def to_day_length
        h = self/HOUR_MS_LENGTH
        d = h/24
        h = h-(d*24)
        r = self - d*24*HOUR_MS_LENGTH - h*HOUR_MS_LENGTH
        m = r / MIN_MS_LENGTH
        s = (r - m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        return sprintf("%d %s, %02d:%02d:%02d", d, "day".check_plural(d), h, m, s)
    end

    def to_sec_length
        m  = self/60
        s  = self%60
        return sprintf("%02d:%02d", m, s)
    end

    def to_std_date(zero_msg = "Unknown")
        return self == 0 ? zero_msg : Time.at(self).strftime("%a %b %d %Y %H:%M:%S")
    end
end

class Utils

    # Returned values by audio_file_exists
    FILE_NOT_FOUND = 0
    FILE_OK        = 1
    FILE_MISPLACED = 2
    FILE_ON_SERVER = 3
    FILE_UNKNOWN   = 4

    # The order matters if the same track is ripped in various format, prefered format first
    AUDIO_EXTS = [".flac", ".ogg", ".mp3"]

    DOWNLOADING = "downloading"

    #
    # Methods intended to deal with the fact that files may now be anywhere on disk rather than just ../
	#
	# Expected format for input params is what is sent by server:
	#   type@:@file_name@:@modification_time
	#
	# file_name is the base name of the file or base name + immediate parent directory
    #
    def Utils::replace_dir_name(file_info)
        type, name, mtime = file_info.split(Cfg::FILE_INFO_SEP)
        return Cfg::instance.dirs[type]+name
    end

    def Utils::has_matching_file?(file_info)
        type, name, mdtime = file_info.split(Cfg::FILE_INFO_SEP)
        local_file = Cfg::instance.dirs[type]+name
        return File::exists?(local_file) && File::mtime(local_file).to_i >= mdtime.to_i
    end

    def Utils::get_file_name(file_info)
        return file_info.split(Cfg::FILE_INFO_SEP)[1]
    end

    #
    # Build a track name from its title and optionally segment name and order
    #
    def Utils::make_track_title(trk_order, trk_title, seg_order, seg_title, add_segment)
        title = ""
        title += trk_order.to_s+". " unless trk_order == 0
        if add_segment == true
            title += seg_title+" - " unless seg_title.empty?
            title += seg_order.to_s+". " unless seg_order == 0
        end
        return title+trk_title
    end



    #
    # Tags a music file with data provided by the track_info class
    #
    def Utils::tag_file(fname, track_infos)
        tags = TagLib::File.new(fname)
        tags.artist = track_infos.seg_art.sname
        tags.album = track_infos.record.stitle
        #tags.title = track_infos.segment.stitle.empty? ? track_infos.title : track_infos.segment.stitle+" - "+track_infos.title
        tags.title = Utils::make_track_title(0, track_infos.track.stitle, track_infos.track.isegorder, track_infos.segment.stitle, true)
        tags.track = track_infos.track.iorder
        tags.year = track_infos.record.iyear
        tags.genre = track_infos.genre
        tags.save
        tags.close
    end


    #
    # Remove dirs from dir up to first non empty directory
    #
    def Utils::remove_dirs(dir)
        while Dir.entries(dir).size < 3 # Remove dir if entries only contains . & ..
            Dir.rmdir(dir)
            Log.instance.info("Source dir #{dir} removed.")
            dir.sub!(/(\/[^\/]+)$/, "")
        end
    end


    #
    # Gets track info from the given track, tags the source file and
    # cp/mv source file to the appropriated location
    #
    def Utils::tag_and_move_file(fname, track_infos)
        tag_file(fname, track_infos)

        root_dir = Cfg::instance.music_dir+track_infos.genre+File::SEPARATOR
        FileUtils.mkpath(root_dir+track_infos.dir)
        FileUtils.mv(fname, root_dir+track_infos.dir+File::SEPARATOR+track_infos.fname+File.extname(fname))
        Log.instance.info("Source #{fname} tagged and moved to "+root_dir+track_infos.dir+File::SEPARATOR+track_infos.fname+File.extname(fname))
        Utils::remove_dirs(File.dirname(fname))
    end



    #
    # Applies a full tag and move file on a directory
    #
    # Primarily intended for use after ripping a disc
    # May also used to retag and move existing tracks
    #
    # Also checks if ripped file names contains a leading 0 on the track number
    # to get file names correctly sorted (thanks sound-juicer for removing it!!!)
    #
    def Utils::tag_and_move_dir(dir, rrecord)
        # Get track count
        trk_count = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{rrecord}")

        # Get recursivelly all music files from the selected dir
        files = []
        Find::find(dir) { |file|
            #puts file;
            files.push([File::basename(file), File::dirname(file)]) if AUDIO_EXTS.include?(File.extname(file).downcase)
        }

        # Check if track numbers contain a leading 0. If not rename the file with a leading 0.
        files.each { |file|
            if file[0] =~ /([^0-9]*)([0-9]+)(.*)/
                next if $2.length > 1
                nfile = $1+"0"+$2+$3
                FileUtils.mv(file[1]+File::SEPARATOR+file[0], file[1]+File::SEPARATOR+nfile)
                puts "File #{file[0]} renamed to #{nfile}"
                file[0] = nfile
            end
        }
        # It looks like the sort method sorts on the first array keeping the second one synchronized with it.
        files.sort! #.each { |file| puts "sorted -> file="+file[1]+" --- "+file[0] }

        # Checks if the track count matches both the database and the directory
        return [trk_count, files.size] if trk_count != files.size

        # Loops through each track
        track_infos = TrackInfos.new
        i = 0
        DBIntf::connection.execute("SELECT rtrack FROM tracks WHERE rrecord=#{rrecord} ORDER BY iorder") do |row|
            yield
            tag_and_move_file(files[i][1]+File::SEPARATOR+files[i][0], track_infos.get_track_infos(row[0]))
            i += 1
        end
        return [trk_count, files.size]
    end

    #
    # Search for an audio file that matches the data given by the TrackInfos class
    # Search is limited to only ONE subdirectory of the root dir, ~/Music for instance
    #
    # Returns the file name if found, an empty string otherwise
    #
    def Utils::search_and_get_audio_file(emitter, tasks, track_infos)
        # If client mode and no local store, download any way in the mfiles directory
        if Cfg::instance.remote? && !Cfg::instance.local_store?
             tasks.new_track_download(emitter, track_info.track.stitle, track_info.track.rtrack)
             return DOWNLOADING
        end

        fname = Utils::audio_file_exists(track_infos).file_name

        # If client mode with local store download file from server if not found on disk
        if fname.empty? && Cfg::instance.remote? && Cfg::instance.local_store?
            tasks.new_track_download(emitter, track_infos.track.stitle, track_infos.track.rtrack)
            return DOWNLOADING
        end
        return fname
    end


    def Utils::search_and_get_audio_file2(emitter, tasks, dbcache)
        # If client mode and no local store, download any way in the mfiles directory
        if Cfg::instance.remote? && !Cfg::instance.local_store?
             tasks.new_track_download(emitter, dbcache.track.stitle, dbcache.track.rtrack)
             return DOWNLOADING
        end

        fname = Utils::audio_file_exists(dbcache).file_name

        # If client mode with local store download file from server if not found on disk
        if fname.empty? && Cfg::instance.remote? && Cfg::instance.local_store?
            tasks.new_track_download(emitter, dbcache.track.stitle, dbcache.track.rtrack)
            return DOWNLOADING
        end
        return fname
    end

    #
    # Check the existence of a file match for a given track.
    #
    # Returns an AudioFileStatus: status (FILE_OK|FILE_MISPLACED|FILE_NOT_FOUND)
    #                             file name (empty if status is FILE_NOT_FOUND)
    #
    #
    def Utils::audio_file_exists(track_infos)
        file = track_infos.get_full_dir+File::SEPARATOR+track_infos.fname
        AUDIO_EXTS.each { |ext| return AudioFileStatus.new(FILE_OK, file+ext) if File::exists?(file+ext) }

        file = File::SEPARATOR+track_infos.dir+File::SEPARATOR+track_infos.fname
        Dir[Cfg::instance.music_dir+"*"].each { |entry|
            next if entry[0] == "." || !FileTest::directory?(entry)
            AUDIO_EXTS.each { |ext| return AudioFileStatus.new(FILE_MISPLACED, entry+file+ext) if File::exists?(entry+file+ext) }
        }
        return AudioFileStatus.new(FILE_NOT_FOUND, "")
    end


    #
    # Remove the file name associated with rtrack from the file system if found.
    #
    def Utils::remove_file(rtrack)
        track_infos = TrackInfos.new.get_track_infos(rtrack)
        fname = audio_file_exists(track_infos).file_name;
        unless fname.empty?
            File.unlink(fname)
            Log.instance.info("File #{fname} removed from file system.")
            Utils::remove_dirs(File.dirname(fname))
        end
    end


    #
    # Returns true if the dir corresponding to the record data is found on disc.
    # Made to speed up search in stats by not checking every track of the record.
    #
    def Utils::record_on_disk?(track_infos)
        Dir[Cfg::instance.music_dir+"*"].each do |entry|
            if FileTest::directory?(entry)
                return true if FileTest::exists?(entry+File::SEPARATOR+track_infos.dir)
            end
        end
        return false
    end

    #
    # Recursively tags all files from a specified directory with given genre
    #
    def Utils::tag_full_dir_to_genre(genre, dir)
        Find::find(dir) { |file|
            if AUDIO_EXTS.inlcude?(File.extname(file).downcase)
                print "Tagging #{file} with genre #{genre}\n"
                tags = TagLib::File.new(file)
                tags.genre = genre
                tags.save
                tags.close
            end
        }
        Log.instance.info("Directory #{dir} tagged with genre #{genre}")
    end

    #
    # Assigns tracks order inside their segment for a given record
    # if it's segmented (new from v4 database)
    #
    def Utils::assign_track_seg_order(rrecord)
        record = RecordDBClass.new.ref_load(rrecord)
        return if record.iissegmented == 0

        segment = SegmentDBClass.new
        DBIntf.connection.execute("SELECT * FROM segments WHERE rrecord=#{record.rrecord};") { |seg_row|
            segment.load_from_row(seg_row)
            seg_order = 1
            DBIntf.connection.execute("SELECT * FROM tracks WHERE rsegment=#{segment.rsegment}  ORDER BY iorder;") { |trk_row|
                DBUtils::log_exec("UPDATE tracks SET isegorder=#{seg_order} WHERE rtrack=#{trk_row[0]};")
                seg_order += 1
            }
        }
    end

    #
    # Try to find a corresponding entry in the db from files tags
    #
    #
    def Utils::search_for_orphans(dir)
        return if dir.empty?

        stats = [0, 0]
        res = File.new(Cfg::instance.rsrc_dir+"orphans.txt", "w")
        Find::find(dir) { |file|
            if AUDIO_EXTS.include?(File.extname(file).downcase)
print "Checking #{file}\n"
                stats[0] += 1
                res << "File #{file} : "
                tags = TagLib::File.new(file)
                artist = DBUtils::ref_from_name(tags.artist, "artist", "sname")
                res << "\n  Artist '#{tags.artist}' not found." if artist.nil?
                record = DBUtils::ref_from_name(tags.album, "record")
                res << "\n  Record '#{tags.album}' not found." if record.nil?
                title = DBUtils::ref_from_name(tags.title, "track")
                res << "\n  Track '#{tags.title}' (#{tags.track}) not found." if title.nil?
                if artist && record && title
                    res << " found in db"
                else
                    res << "\n"
                    stats[1] += 1
                end
                res << "\n"
                tags.close
                yield
            end
        }
        res << "\n#{stats[0]} files, #{stats[1]} not found.\n"
        res.close
    end

    #
    # Scan the entire tracks table and search for a corresponding audio file.
    # Sets the track audioinfo field to the matching file if found
    #
    def Utils::scan_for_audio_files(mw)
        print "No more supported!!!\n"
        return

        total = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM tracks").to_f
        i = 1.0
        DBIntf::connection.execute("SELECT * FROM tracks") do |row|
            file = Utils::audio_file_exists(get_track_info(row[FLD_RTRACK]))[1]
            unless file.empty?
                file.gsub!(Cfg::instance.music_dir, "")
                DBIntf::connection.execute("UPDATE tracks SET saudioinfo=#{file.to_sql} WHERE rtrack=#{row[FLD_RTRACK]};")
            end
        end
    end

    #
    # Returns the cover image for the given record and a default image if none found.
    # If rtrack is not 0, search for a directory named rrecord and a file rtrack.*, allowing to set
    # covers for individual tracks (primary use for compilations).
    #

    def Utils::get_cover_file_name(rrecord, rtrack, irecsymlink)
        # Can't assign irecsymlink to rrecord because if there's a track cover it won't find it
        files = []
        dir = Cfg::instance.covers_dir+rrecord.to_s
        files = Dir[dir+"/"+rtrack.to_s+".*"] if rtrack != 0 && File::directory?(dir)
        files = Dir[dir+".*"] if files.size == 0
        files = Dir[Cfg::instance.covers_dir+irecsymlink.to_s+".*"] if irecsymlink != 0 && files.size == 0
        return files.size > 0 ? files[0] : ""
    end

    def Utils::set_cover(url, rartist, recrartist, rrecord, rtrack)
        fname = URI::unescape(url)
        return false unless fname.match(/^file:\/\//) # We may get http urls...

        fname.sub!(/^file:\/\//, "")
        if recrartist == 0 && rartist != 0
            # We're on a track of a compilation but not on the Compilations
            # so we assign the file to the track rather than the record
            cover_file = Cfg::instance.covers_dir+rrecord.to_s
            File::mkpath(cover_file)
            cover_file += File::SEPARATOR+rtrack.to_s+File::extname(fname)
            ex_name = cover_file+File::SEPARATOR+"ex"+rtrack.to_s+File::extname(fname)
        else
            # Assign file to record
            cover_file = Cfg::instance.covers_dir+rrecord.to_s+File::extname(fname)
            ex_name = Cfg::instance.covers_dir+"ex"+rrecord.to_s+File::extname(fname)
        end
        if File::exists?(cover_file)
            File::unlink(ex_name) if File::exists?(ex_name)
            FileUtils::mv(cover_file, ex_name)
        end
        #File::unlink(cover_file) if File::exists?(cover_file)
        FileUtils::mv(fname, cover_file)

        return true
    end


    #
    #
    #
    def Utils::export_to_xml

        def Utils.new_node(name, row)
            node = XML::Node.new(name)
            row.each_with_index { |field, i|
                tag = XML::Node.new(row.fields[i])
                tag << field
                node << tag
            }
            return node
        end

        def Utils.dump_table(xdoc, table)
            DBIntf::connection.execute("SELECT * FROM #{table}") { |row|
                xdoc.root << new_node(table, row)
            }
        end


        xdoc = XML::Document.new
        xdoc.root = XML::Node.new("XML_CDsDB")
        xdoc.root["version"] = "1";

        ["medias", "collections", "labels", "genres"].each { |table| dump_table(xdoc, table) }

        #DBIntf::connection.execute("SELECT * FROM artists WHERE rartist=273 ORDER BY sname") do |artrow|
        #DBIntf::connection.execute("SELECT * FROM artists ORDER BY sname") do |artrow|
        DBIntf::connection.execute("SELECT DISTINCT (artists.rartist), artists.sname FROM artists INNER JOIN records ON artists.rartist=records.rartist ORDER BY artists.sname") do |artrow|
            xdoc.root << artist = new_node("artist", artrow)
            DBIntf::connection.execute("SELECT * FROM records WHERE rartist=#{artrow[0]} ORDER BY stitle") do |recrow|
                record = new_node("record", recrow)
                DBIntf::connection.execute("SELECT * FROM segments WHERE rrecord=#{recrow[0]} ORDER BY stitle") do |segrow|
                    segment = new_node("segment", segrow)
                    DBIntf::connection.execute("SELECT * FROM tracks WHERE rsegment=#{segrow[0]} ORDER BY iorder") do |trkrow|
                        segment << new_node("track", trkrow)
                    end
                    record << segment
                end
                artist << record
            end
        end
        ["plists", "pltracks", "hostnames", "logtracks"].each { |table| dump_table(xdoc, table) }
        xdoc.save(Cfg::instance.rsrc_dir+"dbexport.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
    end

    def Utils::test_ratings
        lnmax_played = Math.log(DBIntf::connection.get_first_value("SELECT MAX(iplayed) FROM tracks").to_f)
        sql = "SELECT tracks.stitle, tracks.iplayed, tracks.irating, records.stitle, artists.sname FROM tracks " \
              "INNER JOIN records ON tracks.rrecord = records.rrecord " \
              "INNER JOIN segments ON tracks.rsegment = segments.rsegment " \
              "INNER JOIN artists ON segments.rartist = artists.rartist " \
              "WHERE tracks.iplayed > 0;"
        puts sql
        rt = []
        DBIntf::connection.execute(sql) { |row|
            rating = 100.0*(((Math.log(row[1].to_f)/lnmax_played) + (row[2].to_f/2.0)/ (9.0-row[2].to_f)))
            #print Math.log(row[1].to_f), "/", lnmax_played, "\n"
            rt << [rating, row[0]+" by "+row[4]+" from "+row[3]] if rating > 0.0
            #rt << row[0]+" by "+row[4]+" from "+row[3]+"==> "+rating.to_s
        }
        rt.sort! { |t1, t2| t2 <=> t1 }
        File.open(Cfg::instance.rsrc_dir+"ratings.txt", "w") { |file|
            rt.each { |s| file.puts s[0].to_s+": "+s[1] }
        }
    end
end
