
#
# Interface to access the database
#

module DBIntf

    NULL_CDDBID         = 0

    MEDIA_CD            = 0
    MEDIA_AUDIO_FILE    = 5

    class << self
        def connection
            @db ||= SQLite3::Database.new(build_db_name)
        end

        def method_missing(method, *args, &block)
            self.connection.send(method, *args, &block)
        end

        def disconnect
            self.connection.close
            @db = nil
        end

        # Build the database name from the config resource(client)/database(server) dir and the db version
        def build_db_name
            return Cfg.database_dir+"cds.db"
        end

        def load_db_version
            @db_version = self.connection.get_first_value('SELECT * FROM dbversion')
        end

        def db_version
            return @db_version
        end
    end
end

DBIntf.load_db_version
