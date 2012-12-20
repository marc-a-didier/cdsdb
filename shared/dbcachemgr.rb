
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
    end

    def artist(rartist)
#         @artists[rartist] = ArtistDBClass.new.ref_load(rartist) if @artists[rartist].nil?
        if @artists[rartist].nil?
            @artists[rartist] = ArtistDBClass.new.ref_load(rartist)
Trace.log.debug("Artist cache loaded key #{rartist}, size=#{@artists.size}")
        end
        return @artists[rartist]
    end

    def record(rrecord)
#         @records[rrecord] = RecordDBClass.new.ref_load(rrecord) if @records[rrecord].nil?
        if @records[rrecord].nil?
            @records[rrecord] = RecordDBClass.new.ref_load(rrecord)
Trace.log.debug("Record cache loaded key #{rrecord}, size=#{@records.size}")
        end
        return @records[rrecord]
    end

    def segment(rsegment)
#         @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment) if @segments[rsegment].nil?
        if @segments[rsegment].nil?
            @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment)
Trace.log.debug("Segment cache loaded key #{rsegment}, size=#{@segments.size}")
        end
        return @segments[rsegment]
    end

    def track(rtrack)
#         @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack) if @tracks[rtrack].nil?
        if @tracks[rtrack].nil?
            @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack)
Trace.log.debug("Track cache loaded key #{rtrack}, size=#{@tracks.size}")
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

    def clear
        [@artists, @records, @segments, @tracks,
         @genres, @labels, @medias, @collections, @origins].each { |cache| cache.clear }
Trace.log.debug("ALL CACHES cleared")
    end
end


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


    # Alias for DBCache.instance
    def cache
        return DBCache.instance
    end

    def track
        return cache.track(@rtrack)
    end

    def segment
        @rsegment = cache.segment(track.rsegment).rsegment if @rsegment.nil?
        return cache.segment(@rsegment)
    end

    def record
        @rrecord = cache.record(track.rrecord).rrecord if @rrecord.nil?
        return cache.record(@rrecord)
    end

    def artist
        return cache.artist(@rartist)
    end

    def segment_artist
        @rartist = cache.artist(segment.rartist).rartist if @rartist.nil? || @rartist != cache.segment(@rsegment).rartist
        return cache.artist(@rartist)
    end

    def record_artist
        @rartist = cache.artist(record.rartist).rartist if @rartist.nil? || @rartist != cache.record(@rrecord).rartist
        return cache.artist(@rartist)
    end

    def genre
        @rgenre = cache.genre(record.rgenre).rgenre if @rgenre.nil?
        return cache.genre(@rgenre)
    end


    def load_track(rtrack)
        @rtrack = rtrack
        return self
    end

    def load_segment(rsegment)
        @rsegment = rsegment
        return self
    end

    def load_record(rrecord)
        @rrecord = rrecord
        return self
    end

    def load_artist(rartist)
        @rartist = rartist
        return self
    end

    def load_genre(rgenre)
        @rgenre = rgenre
        return self
    end


    def reload_track_cache
        cache.track(@rtrack).sql_load
        return self
    end

    def reload_record_cache
        cache.record(@rrecord).sql_load
        return self
    end

    def reload_segment_cache
        cache.segment(@rsegment).sql_load
        return self
    end
end
