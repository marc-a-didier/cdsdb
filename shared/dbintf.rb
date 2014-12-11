
#
# Interface to access the database
#

module DBIntf

    TBL_GENRES      = "genre"
    TBL_COLLECTIONS = "collection"
    TBL_LABELS      = "label"
    TBL_MEDIAS      = "media"
    TBL_ORIGINS     = "origin"

    TBL_ARTISTS     = "artist"
    TBL_RECORDS     = "record"
    TBL_SEGMENTS    = "segment"
    TBL_TRACKS      = "track"

    TBL_PLISTS      = "plist"
    TBL_PLTRACKS    = "pltrack"


    NULL_CDDBID         = 0

    MEDIA_CD            = 0
    MEDIA_AUDIO_FILE    = 5

    SQL_NUM_TYPES = ["INTEGER", "SMALLINT"]

    class << self
        def connection
            @db ||= SQLite3::Database.new(self.build_db_name)
        end

        def method_missing(method, *args, &block)
            self.connection.send(method, *args, &block)
        end

        def disconnect
            self.connection.close
            @db = nil
        end

        # Build the database name from the config resource(client)/database(server) dir and the db version
        def build_db_name(db_version = CFG.db_version)
            return CFG.database_dir+"cds"+db_version+".db"
        end
    end
end
