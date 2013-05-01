
class DBUtils

    def self.name_from_id(field_val, tbl_name)
        return "" if field_val.nil?
        return CDSDB.get_first_value("SELECT sname FROM #{tbl_name}s WHERE r#{tbl_name}=#{field_val};")
    end

    def self.ref_from_name(name, tbl_name, field = "stitle")
        return CDSDB.get_first_value("SELECT r#{tbl_name} FROM #{tbl_name}s WHERE LOWER(#{field})=LOWER(#{name.to_sql})")
    end

    def self.log_exec(sql, host = "localhost")
        CDSDB.execute(sql)
        LOG.info(sql+" [#{host}]")
    end

    #
    # Execute an sql statements on the local AND remote database if in client mode
    #
    #
    def self.client_sql(sql, want_log = true)
        want_log ? self.log_exec(sql) : CDSDB.execute(sql)
        MusicClient.new.exec_sql(sql) if CFG.remote?
    end

    def self.threaded_client_sql(sql)
        self.log_exec(sql)
        Thread.new { MusicClient.new.exec_sql(sql) } if CFG.remote?
    end

    def self.exec_batch(sql, host)
        CDSDB.transaction { |db|
            db.execute_batch(sql)
            LOG.info(sql+" [#{host}]")
        }
        MusicClient.new.exec_batch(sql) if CFG.remote?
        # May be dangerous to spawn a thread... if request made on the record being inserted,
        # don't know what happen...
#         Thread.new { MusicClient.new.exec_batch(sql) } if CFG.remote?
    end

    def self.get_last_id(short_tbl_name)
        id = CDSDB.get_first_value("SELECT MAX(r#{short_tbl_name}) FROM #{short_tbl_name}s")
        return id.nil? ? 0 : id
    end

    def self.update_track_stats(dblink, hostname)
        return if dblink.track.rtrack <= 0 # Possible when files are dropped into the play queue

        dblink.track.iplayed += 1
        dblink.track.ilastplayed = Time.now.to_i

        sql = "UPDATE tracks SET iplayed=iplayed+1, ilastplayed=#{dblink.track.ilastplayed} WHERE rtrack=#{dblink.track.rtrack};"
        CDSDB.execute(sql)

        rhost = CDSDB.get_first_value("SELECT rhostname FROM hostnames WHERE sname=#{hostname.to_sql};")
        if rhost.nil?
            rhost = self.get_last_id("hostname")+1
            self.log_exec("INSERT INTO hostnames VALUES(#{rhost}, #{hostname.to_sql});")
        end
        sql = "INSERT INTO logtracks VALUES (#{dblink.track.rtrack}, #{dblink.track.ilastplayed}, #{rhost});"
        CDSDB.execute(sql)
    end

    def self.update_record_playtime(rrecord)
        len = CDSDB.get_first_value("SELECT SUM(iplaytime) FROM segments WHERE rrecord=#{rrecord};")
        self.client_sql("UPDATE records SET iplaytime=#{len} WHERE rrecord=#{rrecord};")
    end

    def self.update_segment_playtime(rsegment)
        len = CDSDB.get_first_value("SELECT SUM(iplaytime) FROM tracks WHERE rsegment=#{rsegment};")
        self.client_sql("UPDATE segments SET iplaytime=#{len} WHERE rsegment=#{rsegment};")
    end

    def self.renumber_play_list(rplist)
        i = 1
        sql = ""
        CDSDB.execute(%Q{SELECT rpltrack FROM pltracks WHERE rplist=#{rplist} ORDER BY iorder;}) { |row|
            sql << "UPDATE pltracks SET iorder=#{i} WHERE rpltrack=#{row[0]};\n"
            i += 1
        }
        CDSDB.transaction { |db| db.execute_batch(sql) }
        self.log_exec("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
    end


    #
    # Methods to update the database after I made some big fucking mistakes...
    # Should not exist and never be used.
    #
    def self.check_log_vs_played
        TRACE.debug("Starting log integrity check...")
        tracks = []
        CDSDB.execute("SELECT rtrack, iplayed FROM tracks WHERE iplayed > 0") do |row|
            CDSDB.execute("SELECT COUNT(rtrack), MAX(idateplayed) FROM logtracks WHERE rtrack=#{row[0]}") do |log|
                if log[0] != row[1]
                    puts("Track #{row[0]}: played=#{row[1]}, logged=#{log[0]}, last=#{log[1].to_std_date}")
                    tracks << [row[0], log[0], log[1]]
                end
            end
        end
        TRACE.debug("Check integrity ended with #{tracks.size} mismatch.")

        if tracks.size > 0 && CFG.admin?
            TRACE.debug("Starting tracks update.")
            tracks.each do |track|
                sql = "UPDATE tracks SET iplayed=#{track[1]}, ilastplayed=#{track[2]} WHERE rtrack=#{track[0]}"
                puts sql
                CDSDB.execute(sql)
            end
            TRACE.debug("End tracks update.")
        end
    end

    def self.update_log_time
        CDSDB.execute("SELECT * FROM logtracks WHERE idateplayed=0") do |row|
            last = CDSDB.get_first_value("SELECT ilastplayed FROM tracks WHERE rtrack=#{row[0]}")
            puts "Track #{row[0]} last played on #{last.to_std_date}"
#             CDSDB.execute("UPDATE logtracks SET idateplayed=#{last} WHERE rtrack=#{row[0]} AND idateplayed=0")
        end
    end
end
