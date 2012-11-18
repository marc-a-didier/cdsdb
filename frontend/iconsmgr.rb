
class IconsMgr

    include Singleton

    DEFAULT_64   = "r0&64"
    DEFAULT_128  = "r0&128"
    DEFAULT_FLAG = "f0&16"

    def initialize
        @map = Hash.new
        @map[DEFAULT_64]   = Gdk::Pixbuf.new(Cfg::instance.covers_dir+"default.png",  64,  64)
        @map[DEFAULT_128]  = Gdk::Pixbuf.new(Cfg::instance.covers_dir+"default.png", 128, 128)
        @map[DEFAULT_FLAG] = Gdk::Pixbuf.new(Cfg::instance.flags_dir+"default.svg",   16,  16)
    end

    def track_cover(rrecord, rtrack)
puts "--- IconsMgr check TRACK file ---"
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
puts "--- IconsMgr RECORD disk access size=#{size} ---"        .reverse.green
            # Uncomment next line and comment the line after to get more disk access vs hash size...
            # file_name.empty? ? map_id = "r0&"+size.to_s : @map[map_id] = Gdk::Pixbuf.new(file_name, size, size)
            @map[map_id] = file_name.empty? ? @map["r0&"+size.to_s] : Gdk::Pixbuf.new(file_name, size, size)
puts "___ IconsMgr map size=#{@map.size} ___"
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
end
