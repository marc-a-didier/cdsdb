
# Data access helper for low level classes like the server

#
# DBCache stores DB rows in hashes whose key is the row primary key
#
# It automatically load rows from DB when the refered row is not already in cache.
#
class DBCache

    include Singleton

    def initialize
        @artists  = {}
        @records  = {}
        @segments = {}
        @tracks   = {}
    end

    def artist(rartist)
        @artists[rartist] = ArtistDBClass.new.ref_load(rartist) if @artists[rartist].nil?
        return @artists[rartist]
    end

    def record(rrecord)
        @records[rrecord] = RecordDBClass.new.ref_load(rrecord) if @records[rrecord].nil?
        return @records[rrecord]
    end

    def segment(rsegment)
        @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment) if @segments[rsegment].nil?
        return @segments[rsegment]
    end

    def track(rtrack)
        @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack) if @tracks[rtrack].nil?
        return @tracks[rtrack]
    end
end



class BasicDataStore

    attr_accessor :audio_file, :audio_status

    def initialize
        @rtrack   = nil #TrackDBClass.new
        @rsegment = nil
        @rrecord  = nil
        @rartist  = nil # Consider it's the SEGMENT artist

        @audio_file = ""
        @audio_status = Utils::FILE_UNKNOWN
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

    def segment_artist
        @rartist = cache.artist(segment.rartist).rartist if @rartist.nil? || @rartist != cache.segment(@rsegment).rartist
        return cache.artist(@rartist)
    end

    def record_artist
        @rartist = cache.artist(record.rartist).rartist if @rartist.nil? || @rartist != cache.record(@rrecord).rartist
        return cache.artist(@rartist)
    end

    alias :artist :segment_artist



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

    def reload_track_cache
        cache.track(@rtrack).sql_load
        return self
    end

    # WARNING: does not work anymore. must find a way to bring it back to life!!!
    def load_from_tags(file_name)
        @audio_file = file_name
        @audio_status = Utils::FILE_OK

        # Reinit all members and set all to invalid since there's no link with the DB
        # Hope the garbage collector is well done...
        @track   = TrackDBClass.new
        @segment = SegmentDBClass.new
        @record  = RecordDBClass.new
        @artist  = ArtistDBClass.new

        tags = TagLib::File.new(file_name)
        @artist.sname    = tags.artist
        @record.stitle   = tags.album
        @track.stitle    = tags.title
        @track.iorder    = tags.track
        @track.iplaytime = tags.length*1000
        @record.iyear    = tags.year
        # @genre           = tags.genre # ignore, no way to handle it
        tags.close

        return self
    end

    def set_audio_file(file_name)
        @audio_file = file_name
        @audio_status = Utils::FILE_OK
    end

    def setup_audio_file
        return @audio_status unless @audio_file.empty?

        # If we have a segment, find the intra-segment order. If segmented and isegorder is 0, then the track
        # is alone in its segment.
        track_pos = 0
        if record.segmented?
            track_pos = track.isegorder == 0 ? 1 : track.isegorder
        end
        # If we have a segment, prepend the title with the track position inside the segment
        title = track_pos == 0 ? track.stitle : track_pos.to_s+". "+track.stitle

        # If we have a compilation, the main dir is the record title as opposite to the standard case
        # where it's the artist name
        if record.compile?
            dir = File.join(record.stitle.clean_path, artist.sname.clean_path)
        else
            dir = File.join(artist.sname.clean_path, record.stitle.clean_path)
        end

        fname = sprintf("%02d - %s", track.iorder, title.clean_path)
        genre = DBUtils::name_from_id(record.rgenre, DBIntf::TBL_GENRES)
        dir += "/"+segment.stitle.clean_path unless segment.stitle.empty?

        @audio_file = Cfg::instance.music_dir+genre+"/"+dir+"/"+fname
        @audio_status = audio_file_status(dir, fname)

        return @audio_status
    end

    def audio_file_status(dir, fname)
        Utils::AUDIO_EXTS.each { |ext|
            if File::exists?(@audio_file+ext)
                @audio_file += ext
                return Utils::FILE_OK
            end
        }

        file = "/"+dir+"/"+fname
        Dir[Cfg::instance.music_dir+"*"].each { |entry|
            next if !FileTest::directory?(entry)
            Utils::AUDIO_EXTS.each { |ext|
                if File::exists?(entry+file+ext)
                    @audio_file = entry+file+ext
                    return Utils::FILE_MISPLACED
                end
            }
        }
        return Utils::FILE_NOT_FOUND
    end


end
