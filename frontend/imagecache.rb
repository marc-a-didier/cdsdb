
module XIntf

    module Image

        #
        # Stores pix map of covers into a struct that points to the large and small image.
        # Also the stores the base file name of the image.
        # Flags are handled the old way (copy from IconsMgr).
        #
        class Cache

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
                        # TRACE.debug "XIntf::Image::Cache check pix load small from cache".brown
                        data.small_pix = Gdk::Pixbuf.new(CFG.covers_dir+data.file_name, size, size)
                    end
                    return data.small_pix
                else
                    if data.large_pix.nil?
                        # TRACE.debug "XIntf::Image::Cache check pix load large from cache".brown
                        data.large_pix = Gdk::Pixbuf.new(CFG.covers_dir+data.file_name, size, size)
                    end
                    return data.large_pix
                end
            end

            def load_cover(key, size, file_name)
                fname = CFG.covers_dir+file_name
                # TRACE.debug "XIntf::Image::Cache load_cover from #{fname} size=#{@map.size+1}".red
                if size == SMALL_SIZE
                    @map[key] = ImageData.new(file_name, Gdk::Pixbuf.new(fname, size, size), nil)
                    return @map[key].small_pix
                else
                    @map[key] = ImageData.new(file_name, nil, Gdk::Pixbuf.new(fname, size, size))
                    return @map[key].large_pix
                end
            end

            def set_default_pix(key, size)
                # TRACE.debug "XIntf::Image::Cache for key #{key} rerouted to default".green
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
    end
end

IMG_CACHE = XIntf::Image::Cache.instance
