
# Default random numbers file name
RANDOM_FILE = ENV['HOME']+"/Downloads/randomorg.bin"

#
# Structure returned by check_audio_file
#
AudioFileStatus = Struct.new(:status, :file_name)


# Instatiate global Logger object
LOG = Logger.new(CFG.log_file, 100, 2097152)


# Instatiate global Trace object
TRACE = Logger.new(STDOUT)


# Add some very useful methods to the String class
class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end

    def check_plural(quantity)
        return quantity < 2 ? self : self+"s"
    end

    def to_ms_length
        m, s, ms = self.split(/[:,\.]/)
        return m.to_i*60*1000+s.to_i*1000+ms.to_i
    end

    # Replaces \n in string with true lf to display in memo
    def to_memo
        return self.gsub(/\\n/, "\n")
    end

    # Replaces lf in string with litteral \n to store in the db
    def to_dbstring
        return self.gsub(/\n/, '\n')
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
            dt = Time.at(DateTime.parse(self).to_time)
            return (dt-dt.utc_offset).to_i
        rescue ArgumentError
            return 0
        end
    end

    def to_date
        begin
            return Time.at(Date.parse(self).to_time).to_i
        rescue ArgumentError
            return 0
        end
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


class Fixnum
    def to_sql
        return self.to_s
    end
end

class Float
    def to_sql
        return self.to_s
    end
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


class MyFormatter < REXML::Formatters::Pretty

    def initialize
        super
        @compact = true
        @width = 2048
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
        return CFG.dirs[type]+name
    end

    def Utils::has_matching_file?(file_info)
        type, name, mdtime = file_info.split(Cfg::FILE_INFO_SEP)
        local_file = CFG.dirs[type]+name
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


    # Misc methods to try to get some randomness as by experience every
    # random based run is almost predictible...

    #
    # Another attempt to get more randomness...
    #
    def Utils::init_random_generator
        sysrand = `head -c 8 /dev/random`
        i = rseed = 0
        sysrand.each_byte { |c| rseed |= c << i*8; i += 1 }
p rseed
        srand(rseed)
    end

    def self.get_randoms(max_value, how_many)
        values = []
        i = val = 0
        sysvals = `head -c #{how_many*4} /dev/random`
        sysvals.each_byte { |b|
            val |= b << (i*8)
            if i == 3
                values << (val % max_value)
                i = val = 0
            else
                i += 1
            end
        }
        return values
    end

    # Builds a string from file containing randome bytes from random.org
    def self.str_from_rnd_file(nbytes)
        size = File.size(RANDOM_FILE)
        str = String.new.force_encoding(Encoding::ASCII_8BIT)
        str = IO.binread(RANDOM_FILE, nbytes, size-nbytes)
        File.truncate(RANDOM_FILE, size-nbytes)
        return str
    end

    # Tries to get random numbers from a file of raw bytes downloaded from random.org
    # Reads the how_many*4 last bytes from the file then truncates it and returns an
    # array of values that are max_value at most.
    # If there's no file or it's too short, use reading from /dev/random as a fallback.
    def self.rnd_from_file(max_value, how_many, debug_file)
        wsize = max_value < 16000 ? 2 : 4
        nbytes = how_many*wsize
        file_name = ENV['HOME']+"/Downloads/randomorg.bin"
        unless File.exists?(file_name)
            TRACE.debug("Random file doesn't exist, will use /dev/random".red)
            return self.gen_from_str(`head -c #{nbytes} /dev/random`, max_value, wsize, debug_file)
        end
        size = File.size(file_name)
        if size < nbytes
            TRACE.debug("Random file too short, will use /dev/random".red)
            return self.gen_from_str(`head -c #{nbytes} /dev/random`, max_value, wsize, debug_file)
        else
#             str = String.new.force_encoding(Encoding::ASCII_8BIT)
#             str = IO.binread(file_name, nbytes, size-nbytes)
#             File.truncate(file_name, size-nbytes)
#             return self.gen_from_str(str, max_value, wsize, debug_file)
            return self.gen_from_str(self.str_from_rnd_file(nbytes), max_value, wsize, debug_file)
        end
    end

    # Builds an array of numeric values from bytes of a given string and applies a range
    # of value by using modulo max value
    def self.gen_from_str(str, max_value, wsize, debug_file)
        values = []
        i = val = 0
        str.each_byte { |b|
            debug_file << "%02x " % b
            val |= b << (i*8)
            if i == wsize-1
                values << (val % max_value)
                debug_file << "%08x" % val << " mod " << max_value << " -> " << values.last << "\n"
                i = val = 0
            else
                i += 1
            end
        }
        return values
    end

    # Builds a numeric from bytes taken from a string
    def self.value_from_rnd_str(str, debug_file)
        i = value = 0
        str.each_byte { |b|
            debug_file << "%02x " % b
            value |= b << (i*8)
            i += 1
        }
        return value
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
            LOG.info("Source dir #{dir} removed.")
            dir.sub!(/(\/[^\/]+)$/, "")
        end
    end


    #
    # Gets track info from the given track, tags the source file and
    # cp/mv source file to the appropriated location
    #
    def Utils::tag_and_move_file(fname, track_infos)
        tag_file(fname, track_infos)

        root_dir = CFG.music_dir+track_infos.genre+File::SEPARATOR
        FileUtils.mkpath(root_dir+track_infos.dir)
        FileUtils.mv(fname, root_dir+track_infos.dir+File::SEPARATOR+track_infos.fname+File.extname(fname))
        LOG.info("Source #{fname} tagged and moved to "+root_dir+track_infos.dir+File::SEPARATOR+track_infos.fname+File.extname(fname))
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
        trk_count = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{rrecord}")

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
        CDSDB.execute("SELECT rtrack FROM tracks WHERE rrecord=#{rrecord} ORDER BY iorder") do |row|
#             yield
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
#     def Utils::search_and_get_audio_file(emitter, tasks, track_infos)
#         # If client mode and no local store, download any way in the mfiles directory
#         if CFG.remote? && !CFG.local_store?
#              tasks.new_track_download(emitter, track_info.track.stitle, track_info.track.rtrack)
#              return DOWNLOADING
#         end
#
#         fname = Utils::audio_file_exists(track_infos).file_name
#
#         # If client mode with local store download file from server if not found on disk
#         if fname.empty? && CFG.remote? && CFG.local_store?
#             tasks.new_track_download(emitter, track_infos.track.stitle, track_infos.track.rtrack)
#             return DOWNLOADING
#         end
#         return fname
#     end


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
        Dir[CFG.music_dir+"*"].each { |entry|
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
            LOG.info("File #{fname} removed from file system.")
            Utils::remove_dirs(File.dirname(fname))
        end
    end


    #
    # Returns true if the dir corresponding to the record data is found on disc.
    # Made to speed up search in stats by not checking every track of the record.
    #
    def Utils::record_on_disk?(track_infos)
        Dir[CFG.music_dir+"*"].each do |entry|
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
        LOG.info("Directory #{dir} tagged with genre #{genre}")
    end

    #
    # Assigns tracks order inside their segment for a given record
    # if it's segmented (new from v4 database)
    #
    def Utils::assign_track_seg_order(rrecord)
        record = RecordDBClass.new.ref_load(rrecord)
        return if record.iissegmented == 0

        segment = SegmentDBClass.new
        CDSDB.execute("SELECT * FROM segments WHERE rrecord=#{record.rrecord};") { |seg_row|
            segment.load_from_row(seg_row)
            seg_order = 1
            CDSDB.execute("SELECT * FROM tracks WHERE rsegment=#{segment.rsegment}  ORDER BY iorder;") { |trk_row|
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
        res = File.new(CFG.rsrc_dir+"orphans.txt", "w")
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

        total = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM tracks").to_f
        i = 1.0
        CDSDB.execute("SELECT * FROM tracks") do |row|
            file = Utils::audio_file_exists(get_track_info(row[FLD_RTRACK]))[1]
            unless file.empty?
                file.gsub!(CFG.music_dir, "")
                CDSDB.execute("UPDATE tracks SET saudioinfo=#{file.to_sql} WHERE rtrack=#{row[FLD_RTRACK]};")
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
        dir = CFG.covers_dir+rrecord.to_s
        files = Dir[dir+"/"+rtrack.to_s+".*"] if rtrack != 0 && File::directory?(dir)
        files = Dir[dir+".*"] if files.size == 0
        files = Dir[CFG.covers_dir+irecsymlink.to_s+".*"] if irecsymlink != 0 && files.size == 0
        return files.size > 0 ? files[0] : ""
    end

    def Utils::set_cover(url, rartist, recrartist, rrecord, rtrack)
        fname = URI::unescape(url)
        return false unless fname.match(/^file:\/\//) # We may get http urls...

        fname.sub!(/^file:\/\//, "")
        if recrartist == 0 && rartist != 0
            # We're on a track of a compilation but not on the Compilations
            # so we assign the file to the track rather than the record
            cover_file = CFG.covers_dir+rrecord.to_s
            File::mkpath(cover_file)
            cover_file += File::SEPARATOR+rtrack.to_s+File::extname(fname)
            ex_name = cover_file+File::SEPARATOR+"ex"+rtrack.to_s+File::extname(fname)
        else
            # Assign file to record
            cover_file = CFG.covers_dir+rrecord.to_s+File::extname(fname)
            ex_name = CFG.covers_dir+"ex"+rrecord.to_s+File::extname(fname)
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
            CDSDB.execute("SELECT * FROM #{table}") { |row|
                xdoc.root << new_node(table, row)
            }
        end


        xdoc = XML::Document.new
        xdoc.root = XML::Node.new("XML_CDsDB")
        xdoc.root["version"] = "1";

        ["medias", "collections", "labels", "genres"].each { |table| dump_table(xdoc, table) }

        #CDSDB.execute("SELECT * FROM artists WHERE rartist=273 ORDER BY sname") do |artrow|
        #CDSDB.execute("SELECT * FROM artists ORDER BY sname") do |artrow|
        CDSDB.execute("SELECT DISTINCT (artists.rartist), artists.sname FROM artists INNER JOIN records ON artists.rartist=records.rartist ORDER BY artists.sname") do |artrow|
            xdoc.root << artist = new_node("artist", artrow)
            CDSDB.execute("SELECT * FROM records WHERE rartist=#{artrow[0]} ORDER BY stitle") do |recrow|
                record = new_node("record", recrow)
                CDSDB.execute("SELECT * FROM segments WHERE rrecord=#{recrow[0]} ORDER BY stitle") do |segrow|
                    segment = new_node("segment", segrow)
                    CDSDB.execute("SELECT * FROM tracks WHERE rsegment=#{segrow[0]} ORDER BY iorder") do |trkrow|
                        segment << new_node("track", trkrow)
                    end
                    record << segment
                end
                artist << record
            end
        end
        ["plists", "pltracks", "hostnames", "logtracks"].each { |table| dump_table(xdoc, table) }
        xdoc.save(CFG.rsrc_dir+"dbexport.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
    end

    def Utils::test_ratings
        lnmax_played = Math.log(CDSDB.get_first_value("SELECT MAX(iplayed) FROM tracks").to_f)
        sql = "SELECT tracks.stitle, tracks.iplayed, tracks.irating, records.stitle, artists.sname FROM tracks " \
              "INNER JOIN records ON tracks.rrecord = records.rrecord " \
              "INNER JOIN segments ON tracks.rsegment = segments.rsegment " \
              "INNER JOIN artists ON segments.rartist = artists.rartist " \
              "WHERE tracks.iplayed > 0;"
        puts sql
        rt = []
        CDSDB.execute(sql) { |row|
            rating = 100.0*(((Math.log(row[1].to_f)/lnmax_played) + (row[2].to_f/2.0)/ (9.0-row[2].to_f)))
            #print Math.log(row[1].to_f), "/", lnmax_played, "\n"
            rt << [rating, row[0]+" by "+row[4]+" from "+row[3]] if rating > 0.0
            #rt << row[0]+" by "+row[4]+" from "+row[3]+"==> "+rating.to_s
        }
        rt.sort! { |t1, t2| t2 <=> t1 }
        File.open(CFG.rsrc_dir+"ratings.txt", "w") { |file|
            rt.each { |s| file.puts s[0].to_s+": "+s[1] }
        }
    end

    # tracks is an array of all tracks of a record.
    # replay gain is set for each track and for the record
    def self.compute_replay_gain(tracks, use_thread = true)
        if tracks[0].record.fpeak != 0.0 || tracks[0].record.fgain != 0.0
            LOG.info("Already gained: skipped #{tracks[0].record.stitle}")
TRACE.debug("Already gained: skipped #{tracks[0].record.stitle}".red)
            return
        end

        tracks.each do |trackui|
            unless trackui.playable?
                LOG.info("Not playable: skipped #{trackui.record.stitle}")
TRACE.debug("Missing tracks: skipped #{trackui.record.stitle}".red)
                return
            end
        end

TRACE.debug("Started gain evaluation for #{tracks.first.record.stitle}".green)
        tpeak = tgain = rpeak = rgain = 0.0
        done = error = false

        pipe = Gst::Pipeline.new("getgain")

        pipe.bus.add_watch do |bus, message|
            case message.type
#                 when Gst::Message::Type::ELEMENT
#                     p message
                when Gst::Message::Type::TAG
                    tpeak = message.structure['replaygain-track-peak'] if message.structure['replaygain-track-peak']
                    tgain = message.structure['replaygain-track-gain'] if message.structure['replaygain-track-gain']
                    rpeak = message.structure['replaygain-album-peak'] if message.structure['replaygain-album-peak']
                    rgain = message.structure['replaygain-album-gain'] if message.structure['replaygain-album-gain']
#                     p message.structure
                when Gst::Message::Type::EOS
#                     p message
                    done = true
                when Gst::Message::Type::ERROR
                    p message
                    done = true
                    error = true
            end
            true
        end

        convertor = Gst::ElementFactory.make("audioconvert")
        resample = Gst::ElementFactory.make("audioresample")
        rgana = Gst::ElementFactory.make("rganalysis")
        sink = Gst::ElementFactory.make("fakesink")

        decoder = Gst::ElementFactory.make("decodebin")
        decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
            pad.link(convertor.get_pad("sink"))
            convertor >> resample >> rgana >> sink
        }

        source = Gst::ElementFactory.make("filesrc")

        rgana.num_tracks = tracks.size

        tracks.each do |trackui|
            done = false

            pipe.clear
            pipe.add(source, decoder, convertor, resample, rgana, sink)

            source >> decoder

            # audio file may be empty because of the status cache of the track browser!!!
            trackui.setup_audio_file if trackui.audio_file.empty?

            source.location = trackui.audio_file
            begin
                pipe.play
                while !done
                    Gtk.main_iteration while Gtk.events_pending?
                    sleep(0.01)
                end
            rescue Interrupt
            ensure
                rgana.set_locked_state(true)
                pipe.stop
            end
            trackui.track.fpeak = tpeak
            trackui.track.fgain = tgain

            puts("track gain=#{tgain}, peak=#{tpeak}".cyan)
            puts("rec gain=#{rgain}, peak=#{rpeak}".brown)
        end
        rgana.set_state(Gst::STATE_NULL)

        unless error
            tracks.first.record.fpeak = rpeak
            tracks.first.record.fgain = rgain

            sql = ""
            tracks.each { |trackui|
                statement = trackui.track.generate_update
                sql += statement+"\n" unless statement.empty?
            }
            statement = tracks.first.record.generate_update
            sql += statement unless statement.empty?

            DBUtils.exec_batch(sql, "localhost") unless sql.empty?
#             use_thread ? Thread.new { DBUtils.exec_batch(sql, "localhost") } : DBUtils.exec_batch(sql, "localhost")
        end
    end

    def self.replay_gain_for_genre
TRACE.debug("Start gaining".bold)
        CDSDB.execute("SELECT * FROM records WHERE fpeak=0.0 AND fgain=0.0 AND rgenre=47 LIMIT 50").each do |rec|
            tracks = []
            CDSDB.execute("SELECT * FROM tracks WHERE rrecord=#{rec[0]}") do |track|
                tracks << AudioLink.new.set_record_ref(rec[0]).set_track_ref(track[0])
                tracks.last.setup_audio_file
            end
            self.compute_replay_gain(tracks, false)
        end
TRACE.debug("Finished gaining".bold)
    end
end
