
module DBUtils

    def self.name_from_id(field_val, tbl_name)
        return "" if field_val.nil?
        return DBIntf.get_first_value("SELECT sname FROM #{tbl_name}s WHERE r#{tbl_name}=#{field_val};")
    end

    def self.ref_from_name(name, tbl_name, field = "stitle")
        return DBIntf.get_first_value("SELECT r#{tbl_name} FROM #{tbl_name}s WHERE LOWER(#{field})=LOWER(#{name.to_sql})")
    end

    def self.log_exec(sql, host = "localhost")
        Trace.sql(sql)
        Log.info(sql+" [#{host}]")
        DBIntf.execute(sql)
    end

    #
    # Execute an sql statements on the local AND remote database if in client mode
    #
    #
    def self.client_sql(sql)
        self.log_exec(sql)
        MusicClient.exec_sql(sql) if Cfg.remote?
    end

    def self.threaded_client_sql(sql)
        self.log_exec(sql)
        Thread.new { MusicClient.exec_sql(sql) } if Cfg.remote?
    end

    def self.exec_local_batch(sql, host)
        Trace.sql(sql)
        DBIntf.transaction do |db|
            Log.info(sql+" [#{host}]")
            db.execute_batch(sql)
        end
    end

    def self.exec_batch(sql, host)
        self.exec_local_batch(sql, host)
        MusicClient.exec_batch(sql) if Cfg.remote?
        # May be dangerous to spawn a thread... if request made on the record being inserted,
        # don't know what happen...
#         Thread.new { MusicClient.exec_batch(sql) } if Cfg.remote?
    end

    def self.get_last_id(short_tbl_name)
        id = DBIntf.get_first_value("SELECT MAX(r#{short_tbl_name}) FROM #{short_tbl_name}s")
        return id.nil? ? 0 : id
    end

    def self.get_total_played
        return DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks")
    end

    def self.update_track_stats(dblink, hostname)
        return unless dblink.track.valid? # Possible when files are dropped into the play queue

        dblink.track.iplayed += 1
        dblink.track.ilastplayed = Time.now.to_i
        #dblink.track.sql_update
        sql = dblink.track.generate_update

        host = DBClasses::Host.new
        host.add_new(:sname => hostname) unless host.select_by_field(:sname, hostname, :case_insensitive)

        #DBClasses::LogTracks.new.add_new(:rtrack => dblink.track.rtrack,
        #                               :idateplayed => dblink.track.ilastplayed,
        #                               :rhost => host.rhost)
        sql += DBClasses::LogTracks.new(:rtrack => dblink.track.rtrack,
                                        :idateplayed => dblink.track.ilastplayed,
                                        :rhost => host.rhost).generate_insert

        self.exec_batch(sql, hostname)
    end

    def self.update_record_playtime(rrecord)
        len = DBIntf.get_first_value("SELECT SUM(iplaytime) FROM segments WHERE rrecord=#{rrecord};")
        self.client_sql("UPDATE records SET iplaytime=#{len} WHERE rrecord=#{rrecord};")
    end

    def self.update_segment_playtime(rsegment)
        len = DBIntf.get_first_value("SELECT SUM(iplaytime) FROM tracks WHERE rsegment=#{rsegment};")
        self.client_sql("UPDATE segments SET iplaytime=#{len} WHERE rsegment=#{rsegment};")
    end

    # Generate a sql statement to renumber all tracks from a play list from 1024 to n*1024
    # is_local_only tells wether the statement should also be transmitted to the server or not
    def self.renumber_plist(rplist, is_local_only)
        i = 1024
        sql = ""
        DBIntf.execute(%Q{SELECT rpltrack FROM pltracks WHERE rplist=#{rplist} ORDER BY iorder;}) do |row|
            sql << "UPDATE pltracks SET iorder=#{i} WHERE rpltrack=#{row[0]};\n"
            i += 1024
        end
        is_local_only ? self.exec_local_batch(sql, Socket.gethostname) : self.exec_batch(sql, Socket.gethostname)
        # DBIntf.transaction { |db| db.execute_batch(sql) }
        # self.log_exec("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
    end


    #
    # Methods to update the database after I made some big fucking mistakes...
    # Should not exist and never be used.
    #
    def self.check_log_vs_played
        Trace.debug("Starting log integrity check...")

        tracks = []
        DBIntf.execute("SELECT COUNT(rtrack) FROM logtracks WHERE rtrack <= 0") do |log|
            if log[0] > 0
                Trace.debug("#{log[0]} bad rtrack id(s) found in db.")
                DBIntf.execute("DELETE FROM logtracks WHERE rtrack <= 0")
                Trace.debug("Bad tracks id(s) deleted.")
            else
                Trace.debug("No bad rtrack ids found in db.")
            end
        end

        DBIntf.execute("SELECT COUNT(DISTINCT(rtrack)) FROM logtracks") do |log|
            DBIntf.execute("SELECT COUNT(rtrack) FROM tracks WHERE iplayed > 0") do |track|
                if log[0] != track[0]
                    Trace.debug("Size mismatch, #{log[0]} in log, #{track[0]} in tracks")
                end
            end
        end
        Trace.debug("Check log track count vs track played count ended.")

        iterations = 0
        DBIntf.execute("SELECT DISTINCT(rtrack) FROM logtracks") do |log|
            DBIntf.execute("SELECT rtrack, stitle, iplayed FROM tracks WHERE rtrack=#{log[0]}") do |track|
                if track[2] == 0
                    Trace.debug("Track #{track[0]} (#{track[1]}) played=#{track[2]}")
                end
                iterations += 1
            end
        end
        Trace.debug("Check log track existence in tracks ended (iterations=#{iterations}).")

        iterations = 0
        DBIntf.execute("SELECT rtrack, iplayed FROM tracks WHERE iplayed > 0") do |row|
            DBIntf.execute("SELECT COUNT(rtrack), MAX(idateplayed) FROM logtracks WHERE rtrack=#{row[0]}") do |log|
                if log[0] != row[1]
                    puts("Track #{row[0]}: played=#{row[1]}, logged=#{log[0]}, last=#{log[1].to_std_date}")
                    tracks << [row[0], log[0], log[1]]
                end
                iterations += 1
            end
        end
        Trace.debug("Check dates integrity between tracks and log ended (iterations=#{iterations}).")
        Trace.debug("Check integrity ended with #{tracks.size} mismatches.")
#         return

        if tracks.size > 0 && Cfg.admin
            Trace.debug("Starting tracks update.")
            tracks.each do |track|
                sql = "UPDATE tracks SET iplayed=#{track[1]}, ilastplayed=#{track[2]} WHERE rtrack=#{track[0]}"
                puts sql
                DBIntf.execute(sql)
            end
            Trace.debug("End tracks update.")
        end
    end

    def self.update_log_time
        Trace.debug("Starting check log time.")
        DBIntf.execute("SELECT * FROM logtracks WHERE idateplayed=0") do |row|
            last = DBIntf.get_first_value("SELECT ilastplayed FROM tracks WHERE rtrack=#{row[0]}")
            puts "Track #{row[0]} last played on #{last.to_std_date}"
#             DBIntf.execute("UPDATE logtracks SET idateplayed=#{last} WHERE rtrack=#{row[0]} AND idateplayed=0")
        end
        Trace.debug("End check log time.")
    end
end
