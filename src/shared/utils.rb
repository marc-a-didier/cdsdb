
module Utils

    # Default random numbers file name
    RANDOM_FILE = ENV['HOME']+"/Downloads/randomorg.bin"


    # Misc methods to try to get some randomness as by experience every
    # random based run is almost predictible...

    #
    # Another attempt to get more randomness...
    #
    def self.init_random_generator
        sysrand = `head -c 8 /dev/random`
        i = rseed = 0
        sysrand.each_byte { |c| rseed |= c << i*8; i += 1 }
        Trace.debug("rseed=#{rseed}")
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
            Trace.debug("Random file doesn't exist, will use /dev/random".red)
            return self.gen_from_str(`head -c #{nbytes} /dev/random`, max_value, wsize, debug_file)
        end
        size = File.size(file_name)
        if size < nbytes
            Trace.debug("Random file too short, will use /dev/random".red)
            return self.gen_from_str(`head -c #{nbytes} /dev/random`, max_value, wsize, debug_file)
        else
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
    # Remove dirs from dir up to first non empty directory
    #
    def self.remove_dirs(dir)
        while Dir.entries(dir).size < 3 # Remove dir if entries only contains . & ..
            Dir.rmdir(dir)
            Log.info("Source dir #{dir} removed.")
            dir.sub!(/(\/[^\/]+)$/, "")
        end
    end


    #
    # Recursively get music files from a directory,
    # add a leading 0 if it's not a 2 digits numbering, rename the file it changed
    # and return them in a sorted array of strings
    #
    def self.get_files_to_tag(dir)
        files = []
        Find.find(dir) { |file| files << file if Audio::FILE_EXTS_BY_QUALITY.include?(File.extname(file).downcase) }

        # Check if track numbers contain a leading 0. If not rename the file with a leading 0.
        files.each_with_index do |file, index|
            File.basename(file).match(/([^0-9]*)([0-9]+)(.*)/) do |match|
                if match[2].length < 2
                    new_file = File.join(File.dirname(file), match[1]+'0'+match[2]+match[3])
                    FileUtils.mv(file, new_file)
                    Trace.debug("File #{file[0]} renamed to #{nfile}")
                    files[index] = new_file
                end
            end
        end

        # If we are re-tagging a compile, files will be sorted by artist name since there
        # is one more dir level and it results in a complete mess!
        # Files must be sorted by their track number in any case!
        files.sort! { |f1, f2| File.basename(f1) <=> File.basename(f2) }

        return files
    end

    #
    # Recursively tags all files from a specified directory with given genre
    #
    def self.tag_full_dir_to_genre(genre, dir)
        Find.find(dir) do |file|
            if Audio::FILE_EXTS_BY_QUALITY.inlcude?(File.extname(file).downcase)
                Trace.debug("Tagging #{file} with genre #{genre}")
                tags = TagLib::File.new(file)
                tags.genre = genre
                tags.save
                tags.close
            end
        end
        Log.info("Directory #{dir} tagged with genre #{genre}")
    end

    #
    # Assigns tracks order inside their segment for a given record
    # if it's segmented (new from v4 database)
    #
    def self.assign_track_seg_order(rrecord)
        record = DBClasses::Record.new.ref_load(rrecord)
        return if record.iissegmented == 0

        segment = DBClasses::Segment.new
        DBIntf.execute("SELECT * FROM segments WHERE rrecord=#{record.rrecord};") do |seg_row|
            segment.load_from_row(seg_row)
            seg_order = 1
            DBIntf.execute("SELECT * FROM tracks WHERE rsegment=#{segment.rsegment}  ORDER BY iorder;") do |trk_row|
                DBUtils.log_exec("UPDATE tracks SET isegorder=#{seg_order} WHERE rtrack=#{trk_row[0]};")
                seg_order += 1
            end
        end
    end

    #
    # Try to find a corresponding entry in the db from files tags
    #
    #
    def self.search_for_orphans(dir)
        return if dir.empty?

        stats = [0, 0]
        res = File.new(Cfg.rsrc_dir+"orphans.txt", "w")
        Find::find(dir) { |file|
            if Audio::FILE_EXTS_BY_QUALITY.include?(File.extname(file).downcase)
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
    def self.scan_for_audio_files(mw)
        print "No more supported!!!\n"
        return

        total = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM tracks").to_f
        i = 1.0
        DBIntf.execute("SELECT * FROM tracks") do |row|
            file = Utils::audio_file_exists(get_track_info(row[FLD_RTRACK]))[1]
            unless file.empty?
                file.gsub!(Cfg.music_dir, "")
                DBIntf.execute("UPDATE tracks SET saudioinfo=#{file.to_sql} WHERE rtrack=#{row[FLD_RTRACK]};")
            end
        end
    end


    #
    #
    #
    def self.export_to_xml

        def self.new_node(name, row)
            node = XML::Node.new(name)
            row.each_with_index { |field, i|
                tag = XML::Node.new(row.fields[i])
                tag << field
                node << tag
            }
            return node
        end

        def self.dump_table(xdoc, table)
            DBIntf.execute("SELECT * FROM #{table}") { |row|
                xdoc.root << new_node(table, row)
            }
        end


        xdoc = XML::Document.new
        xdoc.root = XML::Node.new("XML_CDsDB")
        xdoc.root["version"] = "1";

        ["medias", "collections", "labels", "genres"].each { |table| dump_table(xdoc, table) }

        #DBIntf.execute("SELECT * FROM artists WHERE rartist=273 ORDER BY sname") do |artrow|
        #DBIntf.execute("SELECT * FROM artists ORDER BY sname") do |artrow|
        DBIntf.execute("SELECT DISTINCT (artists.rartist), artists.sname FROM artists INNER JOIN records ON artists.rartist=records.rartist ORDER BY artists.sname") do |artrow|
            xdoc.root << artist = new_node("artist", artrow)
            DBIntf.execute("SELECT * FROM records WHERE rartist=#{artrow[0]} ORDER BY stitle") do |recrow|
                record = new_node("record", recrow)
                DBIntf.execute("SELECT * FROM segments WHERE rrecord=#{recrow[0]} ORDER BY stitle") do |segrow|
                    segment = new_node("segment", segrow)
                    DBIntf.execute("SELECT * FROM tracks WHERE rsegment=#{segrow[0]} ORDER BY iorder") do |trkrow|
                        segment << new_node("track", trkrow)
                    end
                    record << segment
                end
                artist << record
            end
        end
        ["plists", "pltracks", "hosts", "logtracks"].each { |table| dump_table(xdoc, table) }
        xdoc.save(Cfg.rsrc_dir+"dbexport.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
    end

    def self.test_ratings
        lnmax_played = Math.log(DBIntf.get_first_value("SELECT MAX(iplayed) FROM tracks").to_f)
        sql = "SELECT tracks.stitle, tracks.iplayed, tracks.irating, records.stitle, artists.sname FROM tracks " \
              "INNER JOIN records ON tracks.rrecord = records.rrecord " \
              "INNER JOIN segments ON tracks.rsegment = segments.rsegment " \
              "INNER JOIN artists ON segments.rartist = artists.rartist " \
              "WHERE tracks.iplayed > 0;"
        puts sql
        rt = []
        DBIntf.execute(sql) { |row|
            rating = 100.0*(((Math.log(row[1].to_f)/lnmax_played) + (row[2].to_f/2.0)/ (9.0-row[2].to_f)))
            #print Math.log(row[1].to_f), "/", lnmax_played, "\n"
            rt << [rating, row[0]+" by "+row[4]+" from "+row[3]] if rating > 0.0
            #rt << row[0]+" by "+row[4]+" from "+row[3]+"==> "+rating.to_s
        }
        rt.sort! { |t1, t2| t2 <=> t1 }
        File.open(Cfg.rsrc_dir+"ratings.txt", "w") { |file|
            rt.each { |s| file.puts s[0].to_s+": "+s[1] }
        }
    end

    def self.replay_gain_for_genre
        Trace.debug("Start gaining".bold)
        DBIntf.execute("SELECT * FROM records WHERE ipeak=0 AND igain=0 AND rgenre=10 LIMIT 50").each do |rec|
            tracks = []
            DBIntf.execute("SELECT * FROM tracks WHERE rrecord=#{rec[0]}") do |track|
                tracks << Audio::Link.new.set_record_ref(rec[0]).set_track_ref(track[0])
                tracks.last.setup_audio_file
            end
            self.compute_replay_gain(tracks, false)
        end
        Trace.debug("Finished gaining".bold)
    end
end
