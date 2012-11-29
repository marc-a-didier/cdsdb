
# Data access helper for low level classes like the server

class BasicDataStore

    attr_accessor :audio_file, :audio_status

    def initialize
        @track   = nil #TrackDBClass.new
#         @track.ref_load(rtrack) unless rtrack == 0
        @segment = nil
        @record  = nil
        @artist  = nil # Consider it's the SEGMENT artist

        @audio_file = ""
        @audio_status = Utils::FILE_UNKNOWN
    end

    def track
        return @track? @track : @track = TrackDBClass.new
    end

    def segment
        if @segment.nil?
            @segment = SegmentDBClass.new
            @segment.ref_load(track.rsegment) #if @track
        end
        return @segment
    end

    def record
        if @record.nil?
            @record = RecordDBClass.new
            @record.ref_load(track.rrecord) #if @track
        end
        return @record
    end

    def artist
        if @artist.nil?
            @artist = ArtistDBClass.new
            @artist.ref_load(segment.rartist) #if @segment
        end
        return @artist
    end

    def load_track(rtrack)
        track.ref_load(rtrack)
        return self
    end

    def load_segment(rsegment)
        segment.ref_load(rsegment)
        return self
    end

    def load_record(rrecord)
        record.ref_load(rrecord)
        return self
    end

    def load_artist(rartist)
        artist.ref_load(rartist)
        return self
    end

    def load_artist_from_record
        artist.ref_load(record.rartist)
        return self
    end

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
