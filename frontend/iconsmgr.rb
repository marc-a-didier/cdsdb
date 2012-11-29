
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
puts "### ImageCache check pix load small from cache".brown
                data.small_pix = Gdk::Pixbuf.new(Cfg::instance.covers_dir+data.file_name, size, size)
            end
            return data.small_pix
        else
            if data.large_pix.nil?
puts "### ImageCache check pix load large from cache".brown
                data.large_pix = Gdk::Pixbuf.new(Cfg::instance.covers_dir+data.file_name, size, size)
            end
            return data.large_pix
        end
    end

    def load_cover(key, size, file_name)
        unless @map[key]
            fname = Cfg::instance.covers_dir+file_name
puts "--- ImageCache load_cover from #{fname} size=#{@map.size+1}".red
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
puts "--- ImageCache for key #{key} rerouted to default".green
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
puts "--- load flag for origin #{rorigin}".red
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
    end
end


class CoverMgr

    attr_reader :pix_key

    def initialize
        reset
    end

    def reset
        @pix_key = ""
    end

    # Returns the full file name for the cover to display.
    # Use @pix_key to search in cache but does NOT change @pix_key!!!
    def file_name(rtrack, rrecord, irecsymlink)
        @pix_key = "t"+rtrack.to_s
        if !ImageCache::instance.has_key(@pix_key)
            load_track_cover(rtrack, rrecord, irecsymlink, ImageCache::SMALL_SIZE)
        end
        return ImageCache::instance.full_name(@pix_key)
    end

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
puts "### CoverMgr search RECORD disk access".red
        if files.size > 0
            return ImageCache::instance.load_cover(@pix_key, size, File::basename(files[0]))
        else
            return ImageCache::instance.set_default_pix(@pix_key, size)
        end
    end

    def load_track_cover(rtrack, rrecord, irecsymlink, size)
        files = Dir[Cfg::instance.covers_dir+rrecord.to_s+"/"+rtrack.to_s+".*"]
puts "### CoverMgr search TRACK disk access".brown
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

    def track_pix(rtrack, rrecord, irecsymlink, size)
        return ImageCache::instance.pix(@pix_key, size) unless @pix_key.empty?

        @pix_key = "t"+rtrack.to_s
        if ImageCache::instance.has_key(@pix_key)
            return ImageCache::instance.pix(@pix_key, size)
        else
            if TrackKeyCache::instance.has_key(@pix_key)
                @pix_key = TrackKeyCache::instance.get_ref_key(@pix_key)
                return ImageCache::instance.pix(@pix_key, size)
            end
            # We go to check if a file exist for this track.
            # If not, will return the record cover or the default cover
            return load_track_cover(rtrack, rrecord, irecsymlink, size)
        end
    end

    def record_pix(rrecord, irecsymlink, size)
        return ImageCache::instance.pix(@pix_key, size) unless @pix_key.empty?

        if record_in_cache?(rrecord, irecsymlink, size)
            return ImageCache::instance.pix(@pix_key, size)
        else
            return load_record_cover(rrecord, irecsymlink, size)
        end
    end
end

class IconsMgr # TODO: rename to ImageCache

    include Singleton

    DEFAULT_64   = "r0&64"
    DEFAULT_128  = "r0&128"
    DEFAULT_FLAG = "f0&16"

    FLAG_SIZE  =  16
    SMALL_SIZE =  64
    LARGE_SIZE = 128

    def initialize
        @map = Hash.new
        @map[DEFAULT_64]   = Gdk::Pixbuf.new(def_record_file, SMALL_SIZE, SMALL_SIZE)
        @map[DEFAULT_128]  = Gdk::Pixbuf.new(def_record_file, LARGE_SIZE, LARGE_SIZE)
        @map[DEFAULT_FLAG] = Gdk::Pixbuf.new(def_flag_file,   FLAG_SIZE,  FLAG_SIZE)
    end

    def def_record_file
        return Cfg::instance.covers_dir+"default.png"
    end

    def def_flag_file
        return Cfg::instance.flags_dir+"default.svg"
    end

    def track_cover(rrecord, rtrack)
puts "--- IconsMgr check TRACK file ---".brown
        file = Dir[Cfg::instance.covers_dir+rrecord.to_s+"/"+rtrack.to_s+".*"]
        return file.size == 0 ? "" : file[0]
    end

    def build_mapid(rrecord, rtrack, irecsymlink, size)
        file_name = ""
        unless rtrack == 0
            map_id = "t"+rtrack.to_s+"&"+size.to_s
            return map_id if @map[map_id]
            fname = track_cover(rrecord, rtrack)
            unless fname.empty?
                @map[map_id] = Gdk::Pixbuf.new(fname, size, size)
                return map_id
            end
        end
        rrecord = irecsymlink unless irecsymlink == 0
        map_id = "r"+rrecord.to_s+"&"+size.to_s
        if @map[map_id].nil?
            file_name = Utils::get_cover_file_name(rrecord, 0, 0)
puts "--- IconsMgr RECORD disk access size=#{size} ---".red
            # Uncomment next line and comment the line after to get more disk access vs hash size...
            # file_name.empty? ? map_id = "r0&"+size.to_s : @map[map_id] = Gdk::Pixbuf.new(file_name, size, size)
            @map[map_id] = file_name.empty? ? @map["r0&"+size.to_s] : Gdk::Pixbuf.new(file_name, size, size)
puts "--- IconsMgr map size=#{@map.size} ---".cyan
        end
        return map_id
    end

    def get_cover(rrecord, rtrack, irecsymlink, size)
        return @map[build_mapid(rrecord, rtrack, irecsymlink, size)]
    end

    def get_cover_key(rrecord, rtrack, irecsymlink, size)
        return build_mapid(rrecord, rtrack, irecsymlink, size)
    end

    def get_flag(rorigin, size)
        map_id = "f"+rorigin.to_s+"&"+size.to_s
        if @map[map_id].nil?
            file = Cfg::instance.flags_dir+rorigin.to_s+".svg"
            File.exists?(file) ? @map[map_id] = Gdk::Pixbuf.new(file, size, size) : map_id = DEFAULT_FLAG
        end
        return @map[map_id]
    end

    def get_pix(hash_key)
        return @map[hash_key]
    end

    def has_key(partial_key, size)
        return !@map[partial_key+"&"+size.to_s].nil?
    end

    def pix(partial_key, size, file_name)
        key = partial_key+"&"+size.to_s
#         @map[key] = Gdk::Pixbuf.new(file_name, size, size) unless @map[key]
        unless @map[key]
            @map[key] = Gdk::Pixbuf.new(file_name, size, size)
puts "--- IconsMgr image LOADED from #{file_name} size=#{@map.size}".red
        end
        return @map[key]
    end
end
