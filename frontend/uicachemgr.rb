
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

    # ImageData struct stores the file name and bot small and large cover image
    # for a record or a track.
    #
    # Flags directly use a Pixbuf because there's only one size and we don't
    # have any use of the file name
    #
    ImageData = Struct.new(:file_name, :small_pix, :large_pix)


    # @map stores either an ImageData struct for covers or a Pixbuf for flags.
    #
    # The key should begin with 'f' for flags, 'r' for records and 't' for tracks
    def initialize
        @map = Hash.new
        @map[DEFAULT_COVER] = ImageData.new(DEF_RECORD_FILE,
                                            Gdk::Pixbuf.new(CFG.covers_dir+DEF_RECORD_FILE, SMALL_SIZE, SMALL_SIZE),
                                            Gdk::Pixbuf.new(CFG.covers_dir+DEF_RECORD_FILE, LARGE_SIZE, LARGE_SIZE))
        @map[DEFAULT_FLAG] = Gdk::Pixbuf.new(CFG.flags_dir+DEF_FLAG_FILE, FLAG_SIZE, FLAG_SIZE)
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
# TRACE.debug "ImageCache check pix load small from cache".brown
                data.small_pix = Gdk::Pixbuf.new(CFG.covers_dir+data.file_name, size, size)
            end
            return data.small_pix
        else
            if data.large_pix.nil?
# TRACE.debug "ImageCache check pix load large from cache".brown
                data.large_pix = Gdk::Pixbuf.new(CFG.covers_dir+data.file_name, size, size)
            end
            return data.large_pix
        end
    end

    def load_cover(key, size, file_name)
#         unless @map[key]
        fname = CFG.covers_dir+file_name
# TRACE.debug "ImageCache load_cover from #{fname} size=#{@map.size+1}".red
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
# TRACE.debug "ImageCache for key #{key} rerouted to default".green
        # Load both sizes at once. No memory wasted since it points to pre-allocated images
        # Unused and unusable method for flags
        @map[key] = ImageData.new(DEF_RECORD_FILE, @map[DEFAULT_COVER].small_pix, @map[DEFAULT_COVER].large_pix)
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
        # Unused and unusable method for flags
        return CFG.covers_dir+@map[key].file_name
    end

    def get_map(key)
        return @map[key]
    end


    def get_flag(rorigin)
        key = "f"+rorigin.to_s
        if @map[key].nil?
# TRACE.debug "--- load flag for origin #{rorigin}".red
            file = CFG.flags_dir+rorigin.to_s+".svg"
            File.exists?(file) ? @map[key] = Gdk::Pixbuf.new(file, FLAG_SIZE, FLAG_SIZE) : key = DEFAULT_FLAG
        end
        return @map[key]
    end

    def default_record_file
        return CFG.covers_dir+DEF_RECORD_FILE
    end

    def default_large_record
        return @map[DEFAULT_COVER].large_pix
    end

    # Scan covers dir and preload all tracks cover. It avoids of checking the existence of
    # a specific directory for a record and search for the cover file each time
    # a new track is selected in the browser.
    def preload_tracks_cover
        Dir[CFG.covers_dir+"*"].each { |entry|
            next unless File::directory?(entry)
            Dir[entry+"/*"].each { |file|
                next if File::directory?(file)
                key =  "t"+File::basename(file).gsub(File::extname(file), "")
                @map[key] = ImageData.new(file.gsub(CFG.covers_dir, ""), nil, nil)
# TRACE.debug("Key #{key} added, file=#{@map[key].file_name}")
           }
        }
    end

    def dump_infos
        TRACE.debug("Image cache size=#{@map.size}")
    end
end

IMG_CACHE = ImageCache.instance

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
        return IMG_CACHE.has_key(@pix_key)
    end

    def get_cover_file_name
        files = Dir[CFG.covers_dir+@pix_key[1..-1]+".*"] # Skip 'r'.
# TRACE.debug "CoverMgr search key #{@pix_key} - disk access".red
        return files.size > 0 ? File::basename(files[0]) : ImageCache::DEF_RECORD_FILE
    end

    # @pix_key is set by record_in_cache? since we always check the hash before the file system
    def load_record_cover(rrecord, irecsymlink, size)
        file = get_cover_file_name
        if file == ImageCache::DEF_RECORD_FILE
            return IMG_CACHE.set_default_pix(@pix_key, size)
        else
            return IMG_CACHE.load_cover(@pix_key, size, file)
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
        if IMG_CACHE.has_key(@pix_key)
            return IMG_CACHE.pix(@pix_key, size)
        else
            return record_pix(rrecord, irecsymlink, size)
        end
    end

    def record_pix(rrecord, irecsymlink, size)
        if record_in_cache?(rrecord, irecsymlink)
            return IMG_CACHE.pix(@pix_key, size)
        else
            return load_record_cover(rrecord, irecsymlink, size)
        end
    end

    # Returns the full file name for the cover to display.
    def file_name(rtrack, rrecord, irecsymlink)
        @pix_key = "t"+rtrack.to_s
        if !IMG_CACHE.has_key(@pix_key) && !record_in_cache?(rrecord, irecsymlink)
            IMG_CACHE.set_file_name(@pix_key, get_cover_file_name)
        end
        return IMG_CACHE.full_name(@pix_key)
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
        @use_record_gain = false
        @pix_key = ""
        return super
    end

    def load_from_tags(file_name)
        @pix_key = ImageCache::DEFAULT_COVER
        return super
    end

    def set_use_of_record_gain
        @use_record_gain = true
        return self
    end

    def use_record_gain?
        return @use_record_gain
    end

    def cover_file_name
        @pix_key.empty? ? file_name(track.rtrack, track.rrecord, record.irecsymlink) :
                          IMG_CACHE.full_name(@pix_key)
    end

    def large_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def large_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def cover_key
        return @pix_key
    end

    def available_on_server?
        if audio_status == AudioLink::NOT_FOUND && CFG.remote?
            if MusicClient.new.check_multiple_audio(track.rtrack.to_s+" ")[0].to_i != AudioLink::NOT_FOUND
                set_audio_status(AudioLink::ON_SERVER)
            end
        end
        return audio_status == AudioLink::ON_SERVER
    end

    def get_audio_file(emitter, tasks)
        # Try to find a local file if status is unknown
        setup_audio_file if audio_status == AudioLink::UNKNOWN || @audio_file.empty?
#         if audio_status == AudioLink::UNKNOWN || @audio_file.empty?
#             setup_audio_file
#             TRACE.debug("Setup audio called for track #{@rtrack.to_s.brown}")
#         end

        # If called from play list, check_on_server is true to get the file in on server
#         if audio_status == AudioLink::NOT_FOUND && CFG.remote?
#             if MusicClient.new.check_multiple_audio(track.rtrack.to_s+" ")[0] != AudioLink::NOT_FOUND
#                 set_audio_status(AudioLink::ON_SERVER)
#             end
#         end

        # If status is on server, get the remote file.
#         return get_remote_audio_file(emitter, tasks) if audio_status == AudioLink::ON_SERVER
        return get_remote_audio_file(emitter, tasks) if available_on_server?

        return audio_status
    end

    def get_remote_audio_file(emitter, tasks)
        if CFG.remote? && CFG.local_store?
            unless tasks.track_in_download?(self)
                tasks.new_track_download(emitter, self)
                set_audio_status(AudioLink::ON_SERVER)
            end
        else
            set_audio_status(AudioLink::NOT_FOUND)
        end
        return audio_status
    end


    def set_cover(url, is_compile)
        fname = URI::unescape(url)
        return self unless fname.match(/^file:\/\//) # We may get http urls...

        fname.sub!(/^file:\/\//, "")
        if record.rartist == 0 && !is_compile
            # We're on a track of a compilation but not on the Compilations
            # so we assign the file to the track rather than the record
            cover_file = CFG.covers_dir+record.rrecord.to_s
            FileUtils::mkpath(cover_file)
            cover_file += File::SEPARATOR+track.rtrack.to_s+File::extname(fname)
            ex_name = cover_file+File::SEPARATOR+"ex"+track.rtrack.to_s+File::extname(fname)
        else
            # Assign file to record
            cover_file = CFG.covers_dir+record.rrecord.to_s+File::extname(fname)
            ex_name = CFG.covers_dir+"ex"+record.rrecord.to_s+File::extname(fname)
        end
        if File::exists?(cover_file)
            File::unlink(ex_name) if File::exists?(ex_name)
            FileUtils::mv(cover_file, ex_name)
        end
        #File::unlink(cover_file) if File::exists?(cover_file)
        FileUtils::mv(fname, cover_file)

        # Force the cache to reload new image
        load_record_cover(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE)

        return self
    end

    def html_track_title(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title).to_html_bold + separator +"by "
        title += @tags.nil? ? segment_artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_track_title_no_track_num(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title, false).to_html_bold + separator +"by "
        title += @tags.nil? ? segment_artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_record_title(separator = "\n")
        return record.stitle.to_html_bold + separator + "by "+record_artist.sname.to_html_italic
    end
end
