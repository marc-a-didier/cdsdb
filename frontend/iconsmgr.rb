
class IconsMgr

    include Singleton

    def initialize
        @map = Hash.new
        @map["r0&64"]  = Gdk::Pixbuf.new(Cfg::instance.covers_dir+"default.png",  64,  64)
        @map["r0&128"] = Gdk::Pixbuf.new(Cfg::instance.covers_dir+"default.png", 128, 128)
        @map["f0&16"]  = Gdk::Pixbuf.new(Cfg::instance.flags_dir+"default.svg",   16,  16)
    end

    def track_cover(rrecord, rtrack)
        file = Dir[Cfg::instance.covers_dir+rrecord.to_s+"/"+rtrack.to_s+".*"]
        return file.size == 0 ? "" : file[0]
    end

    def get_cover(rrecord, rtrack, irecsymlink, size)
        file_name = ""
        unless rtrack == 0
            map_id = "t"+rtrack.to_s+"&"+size.to_s
            return @map[map_id] if @map[map_id]
            fname = track_cover(rrecord, rtrack)
            unless fname.empty?
                @map[map_id] = Gdk::Pixbuf.new(fname, size, size)
                return @map[map_id]
            end
        end
        rrecord = irecsymlink unless irecsymlink == 0
        map_id = "r"+rrecord.to_s+"&"+size.to_s
        if @map[map_id].nil?
            file_name = Utils::get_cover_file_name(rrecord, 0, 0)
            file_name.empty? ? map_id = "r0&"+size.to_s : @map[map_id] = Gdk::Pixbuf.new(file_name, size, size)
        end
        return @map[map_id]
    end

    def get_flag(rorigin, size)
        map_id = "f"+rorigin.to_s+"&"+size.to_s
        if @map[map_id].nil?
            file = Cfg::instance.flags_dir+rorigin.to_s+".svg"
            File.exists?(file) ? @map[map_id] = Gdk::Pixbuf.new(file, size, size) : map_id = "f0&16"
        end
        return @map[map_id]
    end
end
