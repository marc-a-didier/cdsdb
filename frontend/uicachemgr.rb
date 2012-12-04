
#
# Stores pix map of covers into a struct that points to the large and small image.
# Also the stores the base file name of the image.
# Flags are handled the old way (copy from IconsMgr).
#
class ImageCache

    include Singleton

    DEFAULT_FLAG  = "f0"
    DEFAULT_COVER = "r0"

    DEF_RECORD_FILE = "default.png"
    DEF_FLAG_FILE   = "default.svg"

    FLAG_SIZE  =  16
    SMALL_SIZE =  64
    LARGE_SIZE = 128

    ImageData = Struct.new(:file_name, :small_pix, :large_pix)


    def initialize
        @map = Hash.new
        @map[DEFAULT_COVER] = ImageData.new(DEF_RECORD_FILE,
                                            Gdk::Pixbuf.new(Cfg::instance.covers_dir+DEF_RECORD_FILE, SMALL_SIZE, SMALL_SIZE),
                                            Gdk::Pixbuf.new(Cfg::instance.covers_dir+DEF_RECORD_FILE, LARGE_SIZE, LARGE_SIZE))
#         @map[DEFAULT_FLAG] = ImageData.new(DEF_FLAG_FILE, Gdk::Pixbuf.new(Cfg::instance.flags_dir+DEF_FLAG_FILE, FLAG_SIZE, FLAG_SIZE), nil)
        @map[DEFAULT_FLAG] = Gdk::Pixbuf.new(Cfg::instance.flags_dir+DEF_FLAG_FILE, FLAG_SIZE, FLAG_SIZE)
    end

    def has_key(key)
        return !@map[key].nil?
    end

    # Check if requested size exists for the entry
    # No need to say that the entry must exist...
    def check_pix_from_cache(key, size)
        data = @map[key]
        if size == SMALL_SIZE
            if data.small_pix.nil?
Trace.log.debug "ImageCache check pix load small from cache".brown
                data.small_pix = Gdk::Pixbuf.new(Cfg::instance.covers_dir+data.file_name, size, size)
            end
            return data.small_pix
        else
            if data.large_pix.nil?
Trace.log.debug "ImageCache check pix load large from cache".brown
                data.large_pix = Gdk::Pixbuf.new(Cfg::instance.covers_dir+data.file_name, size, size)
            end
            return data.large_pix
        end
    end

    def load_cover(key, size, file_name)
        unless @map[key]
            fname = Cfg::instance.covers_dir+file_name
Trace.log.debug "ImageCache load_cover from #{fname} size=#{@map.size+1}".red
            if size == SMALL_SIZE
                @map[key] = ImageData.new(file_name, Gdk::Pixbuf.new(fname, size, size), nil)
                return @map[key].small_pix
            else
                @map[key] = ImageData.new(file_name, nil, Gdk::Pixbuf.new(fname, size, size))
                return @map[key].large_pix
            end
        end

        return check_pix_from_cache(key, size)
    end

    def set_default_pix(key, size)
Trace.log.debug "ImageCache for key #{key} rerouted to default".green
        if key[0] == "f"
            @map[key] = ImageData.new(DEF_FLAG_FILE, @map[DEFAULT_FLAG].small_pix, nil)
        else
            # Load both sizes at once. No memory wasted since it points to pre-allocated images
            @map[key] = ImageData.new(DEF_RECORD_FILE, @map[DEFAULT_COVER].small_pix, @map[DEFAULT_COVER].large_pix)
        end
        return size == SMALL_SIZE ? @map[key].small_pix : @map[key].large_pix
    end

    def pix(key, size)
        return check_pix_from_cache(key, size)
    end

    def file_name(key)
        return @map[key].file_name
    end

    def full_name(key)
        if key[0] == "f"
            return Cfg::instance.flags_dir+@map[key].file_name
        else
            return Cfg::instance.covers_dir+@map[key].file_name
        end
    end

    def get_map(key)
        return @map[key]
    end


    def get_flag(rorigin)
        key = "f"+rorigin.to_s
        if @map[key].nil?
Trace.log.debug "--- load flag for origin #{rorigin}".red
            file = Cfg::instance.flags_dir+rorigin.to_s+".svg"
            File.exists?(file) ? @map[key] = Gdk::Pixbuf.new(file, FLAG_SIZE, FLAG_SIZE) : key = DEFAULT_FLAG
        end
        return @map[key]
    end

    def default_record_file
        return Cfg::instance.covers_dir+DEF_RECORD_FILE
    end

    def default_large_record
        return @map[DEFAULT_COVER].large_pix
    end
end


#
# TrackKeyCache goal is to map a key for a track cover to it's record image
# if the track has no cover for itself.
#
class TrackKeyCache

    include Singleton

    def initialize
        @key_ref = {}
    end

    def has_key(pix_key)
        return !@key_ref[pix_key].nil?
    end

    def get_ref_key(pix_key)
        return @key_ref[pix_key]
    end

    def add_key(pix_key, ref_pix_key)
        @key_ref[pix_key] = ref_pix_key
Trace.log.debug "TrackKeyCache added key #{pix_key}, size=#{@key_ref.size}".red
    end
end


#
# Module that handle search and caching of image for a track and/or record.
# It feeds the ImageCache with asked for tracks/records and maintains
# the TrackKeyCache hash to speed search for track covers.
#
# The including classes must have a @pix_key string member.
#
module CoverMgr

    def record_in_cache?(rrecord, irecsymlink, size)
        record = irecsymlink unless irecsymlink == 0
        @pix_key = "r"+rrecord.to_s
        return ImageCache::instance.has_key(@pix_key)
    end

    # @pix_key is set by record_in_cache? since we always check the hash before the file system
    def load_record_cover(rrecord, irecsymlink, size)
        # Assign sym link if any
        rrecord = irecsymlink unless irecsymlink == 0

        files = Dir[Cfg::instance.covers_dir+rrecord.to_s+".*"]
Trace.log.debug "CoverMgr search RECORD disk access".red
        if files.size > 0
            return ImageCache::instance.load_cover(@pix_key, size, File::basename(files[0]))
        else
            return ImageCache::instance.set_default_pix(@pix_key, size)
        end
    end

    def load_track_cover(rtrack, rrecord, irecsymlink, size)
        files = Dir[Cfg::instance.covers_dir+rrecord.to_s+"/"+rtrack.to_s+".*"]
Trace.log.debug "CoverMgr search TRACK disk access".brown
        if files.size > 0
            return ImageCache.instance.load_cover(@pix_key, size, rrecord.to_s+"/"+File::basename(files[0]))
        else
            if record_in_cache?(rrecord, irecsymlink, size)
                TrackKeyCache::instance.add_key("t"+rtrack.to_s, @pix_key)
                return ImageCache.instance.pix(@pix_key, size)
            else
                load_record_cover(rrecord, irecsymlink, size)
                TrackKeyCache::instance.add_key("t"+rtrack.to_s, @pix_key)
                return ImageCache.instance.pix(@pix_key, size)
            end
        end
    end


    #
    # Only these 3 methods should be called, the other are for private use.
    #
    # They should be called only of @pix_key is empty. It's faster to get the pix
    # directly from the cache from @pix_key.
    #
    def track_pix(rtrack, rrecord, irecsymlink, size)
        @pix_key = "t"+rtrack.to_s
        if TrackKeyCache::instance.has_key(@pix_key)
            @pix_key = TrackKeyCache::instance.get_ref_key(@pix_key)
            return ImageCache::instance.pix(@pix_key, size)
        end
        # We go to check if a file exist for this track.
        # If not, will return the record cover or the default cover
        return load_track_cover(rtrack, rrecord, irecsymlink, size)
    end

    def record_pix(rrecord, irecsymlink, size)
        if record_in_cache?(rrecord, irecsymlink, size)
            return ImageCache::instance.pix(@pix_key, size)
        else
            return load_record_cover(rrecord, irecsymlink, size)
        end
    end

    # Returns the full file name for the cover to display.
    def file_name(rtrack, rrecord, irecsymlink)
        @pix_key = "t"+rtrack.to_s
        if !ImageCache::instance.has_key(@pix_key)
            if TrackKeyCache::instance.has_key(@pix_key)
                @pix_key = TrackKeyCache::instance.get_ref_key(@pix_key)
            else
                load_track_cover(rtrack, rrecord, irecsymlink, ImageCache::SMALL_SIZE)
            end
        end
        return ImageCache::instance.full_name(@pix_key)
    end
end


#
# Extends AudioLink and include CoverMgr to add UI related functions
# like covers, html titles, etc...
#
class UILink < AudioLink

    include CoverMgr

    def initialize
        super

        reset
    end

    def reset
        super

        @pix_key = ""

        return self
    end

    def init_from_tags(file_name)
        load_from_tags(file_name)
        @pix_key = ImageCache::DEFAULT_COVER
        return self
    end


    def cover_file_name
        @pix_key.empty? ? file_name(track.rtrack, track.rrecord, record.irecsymlink) :
                          ImageCache::instance.full_name(@pix_key)
    end

    def large_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          ImageCache::instance.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          ImageCache::instance.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def large_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          ImageCache::instance.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          ImageCache::instance.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def cover_key
        return @pix_key
    end


    def get_audio_file(emitter, tasks)
        # Try to find a local file if status is unknown
        setup_audio_file if @audio_status == AudioLink::UNKNOWN

        # If status is not found, exit. May be add code to check if on server...
        return @audio_status if @audio_status == AudioLink::NOT_FOUND

        # If status is on server, get the remote file. It can only come from the tracks browser.
        # If file is coming from charts, play list or any other, the track won't be downloaded.
        return get_remote_audio_file(emitter, tasks) if @audio_status == AudioLink::ON_SERVER
    end

    def get_remote_audio_file(emitter, tasks)
        if Cfg::instance.remote? && Cfg::instance.local_store?
            tasks.new_track_download(emitter, track.stitle, track.rtrack)
            @audio_status = AudioLink::ON_SERVER
        else
            @audio_status = AudioLink::NOT_FOUND
        end
        return @audio_status
    end


    def make_track_title(want_segment_title, want_track_number = true)
        title = ""
        title += track.iorder.to_s+". " unless track.iorder == 0 || !want_track_number
        if want_segment_title
            title += segment.stitle+" - " unless segment.stitle.empty?
            title += track.isegorder.to_s+". " unless track.isegorder == 0
        end
        return title+track.stitle
    end

    def html_track_title(want_segment_title, separator = "\n")
        return make_track_title(want_segment_title).to_html_bold + separator +
               "by "+artist.sname.to_html_italic + separator +
               "from "+record.stitle.to_html_italic
    end

    def html_track_title_no_track_num(want_segment_title, separator = "\n")
        return make_track_title(want_segment_title, false).to_html_bold + separator +
               "by "+artist.sname.to_html_italic + separator +
               "from "+record.stitle.to_html_italic
    end

    def html_record_title(separator = "\n")
        return record.stitle.to_html_bold + separator + "by "+record_artist.sname.to_html_italic
    end
end
