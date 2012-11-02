
#
# Extend String and Fixnum classes with a to_sql method to get the content properly formatted
#

class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

class Fixnum
    def to_sql
        return self.to_s
    end
end

# class TrueClass
#     def to_i
#         return 1
#     end
# end
#
# class FalseClass
#     def to_i
#         return 0
#     end
# end

module DBIntf

private
    # Holds the SQLite3 database instance
    @@db = nil

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

    # Returns the current SQLite3 database instance (instantiate a new one if needed)
    #
    # Putain de bordel de merde: les nouvelles version de la lib ont deprecie type_translation
    #                            et maintenant tout est retourne en fonction du type dans la base.
    # Resultat: tout le code a passer en revue...
    #

    def DBIntf::connection
        if @@db.nil?
            @@db = SQLite3::Database.new(DBIntf.build_db_name)
            @@db.type_translation = true
        end
        return @@db
#         @@db.nil? ? @@db = SQLite3::Database.new(DBIntf.build_db_name) : @@db
    end

    # Close and release the database connection
    def DBIntf::disconnect
        return unless @@db
        @@db.close
        @@db = nil
    end

    # Build the database name from the config resource(client)/database(server) dir and the db version
    def DBIntf::build_db_name(db_version = Cfg::instance.db_version)
        return Cfg::instance.database_dir+"cds"+db_version+".db"
    end

end
