
LogTrackDBS = Struct.new(:rlogtrack, :rtrack, :idateplayed, :shostname)
#PListDBS = Struct.new(:rplist, :sname, :iislocal, :idatecreated, :idatemodified)
PLTrackDBS = Struct.new(:rpltrack, :rplist, :rtrack, :iorder)

class DBReorderer

    def initialize
        #newdb = SQLite3::Database.new("../db/cds.neworder.db")
        @outfile = File.new(CFG.database_dir+"reorder.sql", "w")
    end

    def dup_table(table) # Copy table as it, that is there are no change
        CDSDB.execute("SELECT * FROM #{table}") do |row|
            sql = "INSERT INTO #{table} VALUES ("
            row.each { |val| sql += val.to_sql+"," }
#             row.each_with_index do |val, i|
#                 DBIntf::SQL_NUM_TYPES.include?(row.types[i].upcase) ? sql += val+"," : sql += val.to_sql+","
#             end
            sql = sql[0..-2]+");"
            @outfile.puts(sql)
        end
    end

    def process_covers
        Dir[CFG.covers_dir+"*"].each { |entry|
            next if entry == '.' || entry == '..'
            if File::directory?(entry)
                dname = File::basename(entry)
                if dname.to_i > 0
                    cmd = "mkdir #{CFG.rsrc_dir}newcovers/#{@rec_map[dname.to_i]}"
                    #@outfile.puts(cmd)
                    system(cmd)
                end
                Dir[entry+"/*"].each { |subent|
                    next if subent == '.' || subent == '..'
                    name = File::basename(subent).sub(/\.*$/, "")
                    if name.to_i > 0
                        cmd = "cp #{subent} #{CFG.rsrc_dir}newcovers/#{@rec_map[dname.to_i]}/#{@trk_map[name.to_i]}#{File::extname(subent)}"
                        #@outfile.puts(cmd)
                        system(cmd)
                    end
                }
            else
                name = File::basename(entry).sub(/\.*$/, "")
                if name.to_i > 0
                    cmd = "cp #{entry} #{CFG.rsrc_dir}newcovers/#{@rec_map[name.to_i]}#{File::extname(entry)}"
                    #@outfile.puts(cmd)
                    system(cmd)
                end
            end
        }
    end

    def process_plists
        i = 0
        j = 0
        plist = PListDBClass.new
        pltrack = DBClassIntf.new(PLTrackDBS.new)
        CDSDB.execute("SELECT * FROM plists ORDER BY LOWER(sname);") { |row|
            i += 1
            plist.load_from_row(row)
            old_pl = plist.rplist
            plist.rplist = i
            @outfile.puts(plist.generate_insert)

            CDSDB.execute("SELECT * FROM pltracks WHERE rplist=#{old_pl} ORDER BY iorder;") { |row2|
                j += 1
                pltrack.load_from_row(row2)
                pltrack.rpltrack = j
                pltrack.rplist = i
                pltrack.rtrack = @trk_map[pltrack.rtrack.to_i]
                @outfile.puts(pltrack.generate_insert) unless pltrack.rtrack.nil? # If track doesn't exist anymore
            }
        }
    end

    def process_logs
        log = DBClassIntf.new(LogTrackDBS.new)
        CDSDB.execute("SELECT * FROM logtracks;") { |row|
            log.load_from_row(row)
            log.rtrack = @trk_map[log.rtrack]
            @outfile.puts(log.generate_insert)
        }
    end

    def process_tracks
        seg_order = 0
        ntracks_in_seg = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rsegment=#{@old_seg};")
        CDSDB.execute("SELECT * FROM tracks WHERE rsegment=#{@old_seg} ORDER BY iorder;") { |row|
            @track.load_from_row(row)
            @new_trk += 1

            @trk_map[@track.rtrack] = @new_trk

            @track.rtrack   = @new_trk
            @track.rsegment = @new_seg
            @track.rrecord  = @new_rec

            if @record.segmented? && @rec_nsegs > 1 && ntracks_in_seg > 1
                seg_order += 1
                @track.isegorder = seg_order
            else
                @track.isegorder = 0
            end

            @outfile.puts(@track.generate_insert)
        }
    end

    def process_segments
        CDSDB.execute("SELECT * FROM segments WHERE rrecord=#{@old_rec} ORDER BY iorder;") { |row|
            @segment.load_from_row(row)
            @new_seg += 1
            @old_seg = @segment.rsegment

            @segment.rsegment = @new_seg
            @segment.rrecord  = @new_rec
            @segment.rartist  = @art_map[@segment.rartist]
            @outfile.puts(@segment.generate_insert)
            process_tracks
        }
    end

    def process_records
        CDSDB.execute("SELECT * FROM records WHERE rartist=#{@old_art} ORDER BY LOWER(stitle);") { |row|
            @record.load_from_row(row)
            @new_rec += 1
            @old_rec = @record.rrecord

            @rec_map[@record.rrecord] = @new_rec

            @record.rrecord = @new_rec
            @record.rartist = @art_map[@old_art]
            if @record.irecsymlink != 0
                if @rec_map[@record.irecsymlink].nil?
                    puts "lost symlink: #{@old_rec}->#{@record.irecsymlink} (#{@new_rec}->0)"
                    @record.irecsymlink = 0
                else
                    @record.irecsymlink = @rec_map[@record.irecsymlink]
                end
            end
            @outfile.puts(@record.generate_insert)

            @rec_nsegs = CDSDB.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rrecord=#{@old_rec};")

            process_segments
        }
    end

    def run
        ["collections", "medias", "genres", "labels", "origins"].each { |table| dup_table(table) }

        @art_map = []
        @art_map[0] = 0
        @new_art = 0
        @old_art = 0

        @rec_map = []
        @new_rec = 0
        @old_rec = 0

        @new_seg = 0
        @old_seg = 0

        @trk_map = []
        @new_trk = 0

        @artist  = ArtistDBClass.new
        @record  = RecordDBClass.new
        @segment = SegmentDBClass.new
        @track   = TrackDBClass.new

        i = 0
        @artist.ref_load(0)
        @outfile.puts(@artist.generate_insert)
        CDSDB.execute("SELECT * FROM artists WHERE rartist > 0 ORDER BY LOWER(sname);") { |row|
            @artist.load_from_row(row)
            @old_art = @artist.rartist
            @new_art += 1
            @art_map[@old_art] = @new_art
            @artist.rartist = @new_art
            @outfile.puts(@artist.generate_insert)
            process_records
        }

        @artist.ref_load(0)
        @old_art = 0
        @new_art = 0
        process_records

        process_logs

        process_plists

        process_covers

        @outfile.close

        return 0
    end
end
