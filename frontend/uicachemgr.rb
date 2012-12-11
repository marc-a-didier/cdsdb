
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
#         unless @map[key]
        fname = Cfg::instance.covers_dir+file_name
Trace.log.debug "ImageCache load_cover from #{fname} size=#{@map.size+1}".red
        if size == SMALL_SIZE
            @map[key] = ImageData.new(file_name, Gdk::Pixbuf.new(fname, size, size), nil)
            return @map[key].small_pix
        else
            @map[key] = ImageData.new(file_name, nil, Gdk::Pixbuf.new(fname, size, size))
            return @map[key].large_pix
        end
#         end

#         return check_pix_from_cache(key, size)
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

    def set_file_name(key, file_name)
        if @map[key].nil?
            @map[key] = ImageData.new(file_name, nil, nil)
        else # should never get there.
            @map[key].file_name = file_name
        end
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

    def preload_tracks_cover
        Dir[Cfg::instance.covers_dir+"*"].each { |entry|
            next unless File::directory?(entry)
            Dir[entry+"/*"].each { |file|
                next if File::directory?(file)
                key =  "t"+File::basename(file).gsub(File::extname(file), "")
                @map[key] = ImageData.new(file.gsub(Cfg::instance.covers_dir, ""), nil, nil)
Trace.log.debug("Key #{key} added, file=#{@map[key].file_name}")
           }
        }
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

    def record_in_cache?(rrecord, irecsymlink)
        @pix_key = irecsymlink == 0 ? "r"+rrecord.to_s : "r"+irecsymlink.to_s
        return ImageCache::instance.has_key(@pix_key)
    end

    def get_cover_file_name
        files = Dir[Cfg::instance.covers_dir+@pix_key[1..-1]+".*"] # Skip 'r'.
Trace.log.debug "CoverMgr search key #{@pix_key} - disk access".red
        return files.size > 0 ? File::basename(files[0]) : ImageCache::DEF_RECORD_FILE
    end

    # @pix_key is set by record_in_cache? since we always check the hash before the file system
    def load_record_cover(rrecord, irecsymlink, size)
        file = get_cover_file_name
        if file == ImageCache::DEF_RECORD_FILE
            return ImageCache::instance.set_default_pix(@pix_key, size)
        else
            return ImageCache::instance.load_cover(@pix_key, size, file)
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
        if ImageCache::instance.has_key(@pix_key)
            return ImageCache::instance.pix(@pix_key, size)
        else
            return record_pix(rrecord, irecsymlink, size)
        end
    end

    def record_pix(rrecord, irecsymlink, size)
        if record_in_cache?(rrecord, irecsymlink)
            return ImageCache::instance.pix(@pix_key, size)
        else
            return load_record_cover(rrecord, irecsymlink, size)
        end
    end

    # Returns the full file name for the cover to display.
    def file_name(rtrack, rrecord, irecsymlink)
        @pix_key = "t"+rtrack.to_s
        if !ImageCache::instance.has_key(@pix_key) && !record_in_cache?(rrecord, irecsymlink)
            ImageCache::instance.set_file_name(@pix_key, get_cover_file_name)
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

    def load_from_tags(file_name)
        super
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
        return AudioLink::NOT_FOUND
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


    def set_cover(url, is_compile)
        fname = URI::unescape(url)
        return false unless fname.match(/^file:\/\//) # We may get http urls...

        fname.sub!(/^file:\/\//, "")
        if record.rartist == 0 && !is_compile
            # We're on a track of a compilation but not on the Compilations
            # so we assign the file to the track rather than the record
            cover_file = Cfg::instance.covers_dir+record.rrecord.to_s
            File::mkpath(cover_file)
            cover_file += File::SEPARATOR+track.rtrack.to_s+File::extname(fname)
            ex_name = cover_file+File::SEPARATOR+"ex"+track.rtrack.to_s+File::extname(fname)
        else
            # Assign file to record
            cover_file = Cfg::instance.covers_dir+record.rrecord.to_s+File::extname(fname)
            ex_name = Cfg::instance.covers_dir+"ex"+record.rrecord.to_s+File::extname(fname)
        end
        if File::exists?(cover_file)
            File::unlink(ex_name) if File::exists?(ex_name)
            FileUtils::mv(cover_file, ex_name)
        end
        #File::unlink(cover_file) if File::exists?(cover_file)
        FileUtils::mv(fname, cover_file)

        # Force the cache to reload new image
        load_record_cover(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE)

        return true
    end

    def html_track_title(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title).to_html_bold + separator +"by "
        title += @tags.nil? ? artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_track_title_no_track_num(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title, false).to_html_bold + separator +"by "
        title += @tags.nil? ? artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_record_title(separator = "\n")
        return record.stitle.to_html_bold + separator + "by "+record_artist.sname.to_html_italic
    end
end
