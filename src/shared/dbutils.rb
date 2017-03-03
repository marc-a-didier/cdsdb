
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
        EpsdfClient.exec_sql(sql) if Cfg.remote?
    end

    def self.threaded_client_sql(sql)
        self.log_exec(sql)
        Thread.new { EpsdfClient.exec_sql(sql) } if Cfg.remote?
    end

    def self.exec_local_batch(sql, host, log = true)
        Trace.sql(sql)
        DBIntf.transaction do |db|
            Log.info(sql+" [#{host}]") if log
            db.execute_batch(sql)
        end
    end

    def self.exec_batch(sql, host, log = true)
        self.exec_local_batch(sql, host, log)
        EpsdfClient.exec_batch(sql) if Cfg.remote?
        # May be dangerous to spawn a thread... if request made on the record being inserted,
        # don't know what happen...
#         Thread.new { EpsdfClient.exec_batch(sql) } if Cfg.remote?
    end

    def self.get_last_id(short_tbl_name)
        id = DBIntf.get_first_value("SELECT MAX(r#{short_tbl_name}) FROM #{short_tbl_name}s")
        return id.nil? ? 0 : id
    end

    def self.get_total_played
        return DBIntf.get_first_value("SELECT COUNT(rtrack) FROM logtracks")
    end

    def self.update_track_stats(dblink)
        return unless dblink.track.valid? # Possible when files are dropped into the play queue

        hostname = Cfg.hostname

        dblink.track.ilastplayed = Time.now.to_i
        sql = dblink.track.generate_inc_update
        dblink.track.iplayed += 1

        host = DBClasses::Host.new
        host.add_new(:sname => hostname) unless host.select_by_field(:sname, hostname)

        sql += DBClasses::LogTracks.new(:rtrack => dblink.track.rtrack,
                                        :idateplayed => dblink.track.ilastplayed,
                                        :rhost => host.rhost).generate_insert

        self.exec_batch(sql, hostname, false)
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
        sql = ''.dup
        DBIntf.execute(%Q{SELECT rpltrack FROM pltracks WHERE rplist=#{rplist} ORDER BY iorder;}) do |row|
            sql << "UPDATE pltracks SET iorder=#{i} WHERE rpltrack=#{row[0]};\n"
            i += 1024
        end
        is_local_only ? self.exec_local_batch(sql, Cfg.hostname) : self.exec_batch(sql, Cfg.hostname)
        # DBIntf.transaction { |db| db.execute_batch(sql) }
        # self.log_exec("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
    end


    #
    # Methods to update the database after I made some big fucking mistakes...
    # Should not exist and never be used.
    #
    def self.check_log_vs_played(is_full_check)
        Trace.debug("Starting log integrity check...")

        Trace.debug('Step 1: Checking for bad tracks ids in logtracks table')
        DBIntf.execute("SELECT COUNT(rtrack) FROM logtracks WHERE rtrack <= 0") do |log|
            if log[0] > 0
                Trace.debug("#{log[0]} bad rtrack id(s) found in db.")
                self.client_sql("DELETE FROM logtracks WHERE rtrack <= 0")
                Trace.debug("Bad tracks id(s) deleted.")
            else
                Trace.debug("No bad rtrack ids found in db.")
            end
        end
        Trace.debug('Step 1: finished')

        Trace.debug('Step 2: Checking if play count match between tracks and logtracks')
        DBIntf.execute("SELECT COUNT(DISTINCT(rtrack)) FROM logtracks") do |log|
            DBIntf.execute("SELECT COUNT(rtrack) FROM tracks WHERE iplayed > 0") do |track|
                if log[0] != track[0]
                    Trace.debug("Size mismatch, #{log[0]} in log, #{track[0]} in tracks")
                end
            end
        end
        Trace.debug('Step 2: finished')

        Trace.debug('Step 3: Checking if logtracks rtrack matches tracks entry')
        iterations = 0
        DBIntf.execute("SELECT DISTINCT(rtrack) FROM logtracks") do |log|
            DBIntf.execute("SELECT rtrack, stitle, iplayed FROM tracks WHERE rtrack=#{log[0]}") do |track|
                if track[2] == 0
                    Trace.debug("Track #{track[0]} (#{track[1]}) played=#{track[2]}")
                end
                iterations += 1
            end
        end
        Trace.debug("Step 3: finished after #{iterations} iterations")

        Cfg.set_last_integrity_check(0) if is_full_check
        Trace.debug('Step 4: Checking if tracks play count and date match logtracks entries')
        Trace.debug("        Starting from #{Cfg.last_integrity_check.to_std_date}")
        tracks = []
        iterations = 0
        DBIntf.execute("SELECT rtrack, iplayed FROM tracks WHERE ilastplayed >= #{Cfg.last_integrity_check}") do |row|
            DBIntf.execute("SELECT COUNT(rtrack), MAX(idateplayed) FROM logtracks WHERE rtrack=#{row[0]}") do |log|
                if log[0] != row[1]
                    puts("Track #{row[0]}: played=#{row[1]}, logged=#{log[0]}, last=#{log[1].to_std_date}")
                    tracks << [row[0], log[0], log[1]]
                end
                iterations += 1
            end
        end
        Trace.debug("Step 4: finished after #{iterations} iterations")

        if tracks.size > 0
            if Cfg.admin
                Trace.debug("Starting tracks update.")
                sql = ''.dup
                tracks.each do |track|
                    sql << "UPDATE tracks SET iplayed=#{track[1]}, ilastplayed=#{track[2]} WHERE rtrack=#{track[0]};\n"
                end
                Trace.debug("Repair: \n#{sql}")
                self.exec_batch(sql, Cfg.hostname)
                Trace.debug("End tracks update.")

                # Save last check only if repaired so can restart in admin mode
                Cfg.set_last_integrity_check(DBIntf.get_first_value('SELECT MAX(idateplayed) FROM logtracks'))
            else
                Trace.debug("Not in admin mode, skipping repair statements.")
            end
        else
            Cfg.set_last_integrity_check(DBIntf.get_first_value('SELECT MAX(idateplayed) FROM logtracks'))
            Trace.debug("Check integrity ended with no mismatch.")
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

    def self.scan_for_orphan_artists
        DBIntf.execute("SELECT * FROM artists") do |art_row|
            if DBIntf.get_first_value("SELECT COUNT(rrecord) FROM records WHERE rartist=#{art_row[0]}") == 0
                if DBIntf.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rartist=#{art_row[0]}") == 0
                    puts("Artist '#{art_row[1]}', ref #{art_row[0]}, has no record nor segment")
                    if Cfg.admin
                        self.client_sql("DELETE FROM artists WHERE rartist=#{art_row[0]}")
                        puts("Artist '#{art_row[1]}' removed from DB")
                    end
                end
            end
        end
    end

    def self.scan_for_orphan_records
        DBIntf.execute("SELECT * FROM records") do |rec_row|
            if DBIntf.get_first_value("SELECT COUNT(rartist) FROM artists WHERE rartist=#{rec_row[2]}") == 0
                puts("Record '#{rec_row[3]}', ref #{rec_row[0]}, has a not found artist")
            end
        end
    end

    def self.scan_for_orphan_segments
        DBIntf.execute("SELECT * FROM segments") do |seg_row|
            if DBIntf.get_first_value("SELECT COUNT(rartist) FROM artists WHERE rartist=#{seg_row[2]}") == 0
                puts("Segment '#{seg_row[4]}', ref #{seg_row[0]}, has a not found artist")
            end
            if DBIntf.get_first_value("SELECT COUNT(rrecord) FROM records WHERE rrecord=#{seg_row[1]}") == 0
                puts("Segment '#{seg_row[4]}', ref #{seg_row[0]}, has a not found record")
            end
        end
    end

    def self.scan_for_orphan_tracks
        DBIntf.execute("SELECT * FROM tracks") do |trk_row|
            if DBIntf.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rsegment=#{trk_row[1]}") == 0
                puts("Track '#{trk_row[5]}', ref #{trk_row[0]}, has a not found segment")
            end
            if DBIntf.get_first_value("SELECT COUNT(rrecord) FROM records WHERE rrecord=#{trk_row[2]}") == 0
                puts("Track '#{trk_row[5]}', ref #{trk_row[0]}, has a not found record")
            end
        end
    end
end
