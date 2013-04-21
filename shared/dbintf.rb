
#
# Interface to access the database
#

class DBIntf

    include Singleton

public
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


    def initialize
        @db = nil
    end

    # Returns the current SQLite3 database instance (instantiate a new one if needed)
    #
    # Putain de bordel de merde: les nouvelles version de la lib ont deprecie type_translation
    #                            et maintenant tout est retourne en fonction du type dans la base.
    # Resultat: tout le code a passer en revue...
    #

    def self.connection
        return @db.nil? ? SQLite3::Database.new(build_db_name) : @db
    end

    # Close and release the database connection
    def self.disconnect
        return unless @db
        @db.close
        @db = nil
    end

    # Build the database name from the config resource(client)/database(server) dir and the db version
    def self.build_db_name(db_version = CFG.db_version)
        return CFG.database_dir+"cds"+db_version+".db"
    end

end

CDSDB = DBIntf.connection
