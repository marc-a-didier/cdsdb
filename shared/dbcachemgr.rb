
# Data access helper for low level classes like the server

#
# DBCache stores DB rows in hashes whose key is the row primary key
#
# It automatically load rows from DB when the refered row is not already in cache.
#

class DBCache

    include Singleton

    def initialize
        @artists     = {}
        @records     = {}
        @segments    = {}
        @tracks      = {}
        @genres      = {}
        @labels      = {}
        @medias      = {}
        @collections = {}
        @origins     = {}

        # Keep tracks of audio file status for a track, avoiding to
        # repeatetly ask to the server if the track exists in client mode.
        # Closely related to the track cache.
        @audio_status = {}
    end

    def artist(rartist)
#         @artists[rartist] = ArtistDBClass.new.ref_load(rartist) if @artists[rartist].nil?
        if @artists[rartist].nil?
            @artists[rartist] = ArtistDBClass.new.ref_load(rartist)
# TRACE.debug("Artist cache loaded key #{rartist}, size=#{@artists.size}")
        end
        return @artists[rartist]
    end

    def record(rrecord)
#         @records[rrecord] = RecordDBClass.new.ref_load(rrecord) if @records[rrecord].nil?
        if @records[rrecord].nil?
            @records[rrecord] = RecordDBClass.new.ref_load(rrecord)
# TRACE.debug("Record cache loaded key #{rrecord}, size=#{@records.size}")
        end
        return @records[rrecord]
    end

    def segment(rsegment)
#         @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment) if @segments[rsegment].nil?
        if @segments[rsegment].nil?
            @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment)
# TRACE.debug("Segment cache loaded key #{rsegment}, size=#{@segments.size}")
        end
        return @segments[rsegment]
    end

    def track(rtrack)
#         @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack) if @tracks[rtrack].nil?
        if @tracks[rtrack].nil?
            @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack)
            @audio_status[rtrack] = 4 # AudioLink::UNKNOWN default value
# TRACE.debug("Track cache loaded key #{rtrack}, size=#{@tracks.size}")
        end
        return @tracks[rtrack]
    end

    def genre(rgenre)
        @genres[rgenre] = GenreDBClass.new.ref_load(rgenre) if @genres[rgenre].nil?
        return @genres[rgenre]
    end

    def label(rlabel)
        @labels[rlabel] = LabelDBClass.new.ref_load(rlabel) if @labels[rlabel].nil?
        return @labels[rlabel]
    end

    def media(rmedia)
        @medias[rmedia] = MediaDBClass.new.ref_load(rmedia) if @medias[rmedia].nil?
        return @medias[rmedia]
    end

    def collection(rcollection)
        @collections[rcollection] = CollectionDBClass.new.ref_load(rcollection) if @collections[rcollection].nil?
        return @collections[rcollection]
    end

    def origin(rorigin)
        @origins[rorigin] = OriginDBClass.new.ref_load(rorigin) if @origins[rorigin].nil?
        return @origins[rorigin]
    end

    def set_audio_status(rtrack, status)
        @audio_status[rtrack] = status
    end

    def audio_status(rtrack)
        return @audio_status[rtrack]
    end

    def clear
#         instance_variables.each { |cache| cache.clear } # Marche pas!!!???
        [@artists, @records, @segments, @tracks, @audio_status,
         @genres, @labels, @medias, @collections, @origins].each { |cache| cache.clear }
TRACE.debug("ALL CACHES cleared")
    end

    # Set audio status from a status to another
    # Primary use is when switching from local mode to client mode (not found -> unknown)
    # and from client to local mode (on server -> not found)
    def set_audio_status_from_to(from_value, to_value)
        @audio_status.each { |key, value| @audio_status[key] = to_value if value == from_value }
    end

    def dump_infos
        TRACE.debug("Artist cache size=#{@artists.size}")
        TRACE.debug("Record cache size=#{@records.size}")
        TRACE.debug("Segment cache size=#{@segments.size}")
        TRACE.debug("Track cache size=#{@tracks.size}")
        TRACE.debug("Genre cache size=#{@genres.size}")
        TRACE.debug("Label cache size=#{@labels.size}")
        TRACE.debug("Media cache size=#{@medias.size}")
        TRACE.debug("Collection cache size=#{@collections.size}")
        TRACE.debug("Origin cache size=#{@origins.size}")
        TRACE.debug("Audio status cache size=#{@audio_status.size}")
    end
end

DBCACHE = DBCache.instance

#
# This class keeps references to the primary key of its tables and makes
# load on demand into the cache.
#
class DBCacheLink

    def initialize
        reset
    end

    def reset
        @rtrack   = nil
        @rsegment = nil
        @rrecord  = nil
        @rartist  = nil # Consider it's the SEGMENT artist
        @rgenre   = nil

        return self
    end


    #
    # Methods that load the row from the primary key
    # First search in cache and load from db if not found
    #
    # Tries to feed the artist primary key from record or segment if possible
    #
    def track
        return DBCACHE.track(@rtrack)
    end

    def segment
        @rsegment = DBCACHE.segment(track.rsegment).rsegment if @rsegment.nil?
        return DBCACHE.segment(@rsegment)
    end

    def record
        @rrecord = DBCACHE.record(track.rrecord).rrecord if @rrecord.nil?
        return DBCACHE.record(@rrecord)
    end

    def artist
        return DBCACHE.artist(@rartist)
    end

    def segment_artist
        @rartist = DBCACHE.artist(segment.rartist).rartist if @rartist.nil? || @rartist != DBCACHE.segment(@rsegment).rartist
        return DBCACHE.artist(@rartist)
    end

    def record_artist
        @rartist = DBCACHE.artist(record.rartist).rartist if @rartist.nil? || @rartist != DBCACHE.record(@rrecord).rartist
        return DBCACHE.artist(@rartist)
    end

    def genre
        @rgenre = DBCACHE.genre(record.rgenre).rgenre if @rgenre.nil?
        return DBCACHE.genre(@rgenre)
    end

    def set_audio_status(status)
        DBCACHE.set_audio_status(@rtrack, status)
        return self
    end

    def audio_status
        return DBCACHE.audio_status(@rtrack)
    end


    #
    # Methods to check if a reference has been set for the cache to get it
    #
    def valid_track_ref?
        return !@rtrack.nil?
    end

    def valid_segment_ref?
        return !@rsegment.nil?
    end

    def valid_record_ref?
        return !@rrecord.nil?
    end

    def valid_artist_ref?
        return !@rartist.nil?
    end


    #
    # These methods just set the primary key for futur use but DO NOT load the row
    #
    def set_track_ref(rtrack)
        @rtrack = rtrack
        return self
    end

    def set_segment_ref(rsegment)
        @rsegment = rsegment
        return self
    end

    def set_record_ref(rrecord)
        @rrecord = rrecord
        return self
    end

    def set_artist_ref(rartist)
        @rartist = rartist
        return self
    end

    def set_genre_ref(rgenre)
        @rgenre = rgenre
        return self
    end


    #
    # Methods to keep the cache in sync with the db in case of modifications
    #
    def reload_track_cache
        DBCACHE.track(@rtrack).sql_load
        return self
    end

    def reload_record_cache
        DBCACHE.record(@rrecord).sql_load
        return self
    end

    def reload_segment_cache
        DBCACHE.segment(@rsegment).sql_load
        return self
    end

    def reload_artist_cache
        DBCACHE.artist(@rartist).sql_load
        return self
    end

    def flush_main_tables
        [DBCACHE.track(@rtrack), DBCACHE.record(@rrecord),
         DBCACHE.segment(@rsegment), DBCACHE.artist(@rartist)].each { |dbclass| dbclass.sql_update }
    end
end
