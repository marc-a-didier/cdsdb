
#
# Interface to access the database
#

module DBIntf

    NULL_CDDBID         = 0

    MEDIA_CD            = 0
    MEDIA_AUDIO_FILE    = 5

    DB_FILE_NAME = 'cds.db'
    BACKUP_EXT   = '.back'

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
            return Cfg.database_dir+DB_FILE_NAME
        end

        def load_db_version
            @db_version = self.connection.get_first_value('SELECT * FROM dbversion')
        end

        def db_version
            return @db_version
        end

        def swap_databases
            file = self.build_db_name
            File.unlink(file+BACKUP_EXT) if File.exists?(file+BACKUP_EXT)
            self.disconnect
            FileUtils.mv(file, file+BACKUP_EXT)
            FileUtils.mv(file+Epsdf::Protocol::DOWNLOAD_EXT, file)
        end
    end
end

DBIntf.load_db_version
