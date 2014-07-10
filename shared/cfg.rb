
class Cfg

    include Singleton

    # Client/Server transmission block size
    TX_BLOCK_SIZE = 128*1024
    MSG_EOL       = "EOL"
    FILE_INFO_SEP = "@:@"

    MSG_CONTINUE   = "CONTINUE"
    MSG_CANCELLED  = "CANCELLED"
    STAT_CONTINUE  = 1
    STAT_CANCELLED = 0

    DIR_NAMES       = ["covers", "icons", "flags", "src", "db"]
    SERVER_RSRC_DIR = "../../"
    PREFS_FILE      = "prefs.yml"
    LOG_FILE        = "cdsdb.log"


    CONFIG = { "dbversion" => "6.0",
               "windows" => {
                    "prefs_dialog" => {
                        "prefs_cb_shownotifications" => { "active=" => [true] },
                        "prefs_entry_notifduration"  => { "text=" => ["4"] },
                        "prefs_fc_musicdir"          => { "current_folder=" => [ENV[HOME]+"/Music/"] },
                        "prefs_fc_rsrcdir"           => { "current_folder=" => "./../../"] },
                        "prefs_entry_cddevice"       => { "text=" => ["/dev/cdrom"] },
                        "prefs_entry_server"         => { "text=" => ["madd510"] },
                        "prefs_entry_port"           => { "text=" => ["32666"] },
                        "prefs_entry_blksize"        => { "text=" => ["256000"] },
                        "prefs_chkbtn_localstore"    => { "active=" => [true] },
                        "prefs_cb_liveupdate"        => { "active=" => [true] },
                        "prefs_cb_logtrackfile"      => { "active=" => [false] },
                        "prefs_entry_maxitems"       => { "text=" => ["100"] }
                    }
               },
               "menus" => {}
             }

    attr_reader   :server, :port, :tx_block_size, :music_dir, :rsrc_dir, :dirs, :max_items, :cd_device
    attr_accessor :db_version

    def initialize
        dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
        @config_dir = File.join(dir, 'cdsdb/')
        FileUtils::mkpath(@config_dir) unless File::exists?(@config_dir)

        @remote = false
        @server = "localhost"
        @port = 32666
        @local_store = true
        @music_dir = ENV["HOME"]+"/Music/"
        @rsrc_dir = SERVER_RSRC_DIR # Default to ../../
        @notifcations = true
        @notif_duration = 5
        @admin_mode = false
        @live_charts_update = false
        @log_played_tracks = false
        @tx_block_size = TX_BLOCK_SIZE
        @dirs = {}
        @max_items = 100
        @db_version = "6.0"
        @cd_device = "/dev/cdrom"
    end

    def set_dirs
        DIR_NAMES.each { |dir| @dirs[dir] = @rsrc_dir+dir+"/" }
        @dirs[DIR_NAMES.last] = database_dir
    end

    def load
        @cfg = nil
        if File.exists?(prefs_file)
            @cfg = YAML.load_file(prefs_file)
            load_default_config if @cfg["windows"]["prefs_dialog"].nil?
            @cfg = yml["windows"]["prefs_dialog"]
        else
            load_default_config
        end

        @cfg = @cfg["windows"]["prefs_dialog"]

        @server = @cfg[UIConsts::PREFS_ENTRY_SERVER]["text="][0]
        @port = @cfg[UIConsts::PREFS_ENTRY_PORT]["text="][0].to_i
        @tx_block_size = @cfg[UIConsts::PREFS_ENTRY_BLKSIZE]["text="][0].to_i
        @music_dir = @cfg[UIConsts::PREFS_FC_MUSICDIR]["current_folder="][0]+"/"
        @rsrc_dir = @cfg[UIConsts::PREFS_FC_RSRCDIR]["current_folder="][0]+"/"
        @local_store = @cfg[UIConsts::PREFS_CHKBTN_LOCALSTORE]["active="][0]
        @notifications = @cfg[UIConsts::PREFS_CB_SHOWNOTIFICATIONS]["active="][0]
        @notif_duration = @cfg[UIConsts::PREFS_ENTRY_NOTIFDURATION]["text="][0].to_i
        @live_charts_update = @cfg[UIConsts::PREFS_CB_LIVEUPDATE]["active="][0]
        @log_played_tracks = @cfg[UIConsts::PREFS_CB_LOGTRACKFILE]["active="][0]
        @max_items = @cfg[UIConsts::PREFS_ENTRY_MAXITEMS]["text="][0].to_i
        @cd_device = @cfg[UIConsts::PREFS_CD_DEVICE]["text="][0]

        set_dirs
        @db_version = yml["dbversion"]

        return self

        xdoc = nil
        File::open(prefs_file, "r") { |file| xdoc = REXML::Document.new(file) } if File::exists?(prefs_file)
        if xdoc.nil? || REXML::XPath.first(xdoc.root, "windows/prefs_dialog").nil?
            set_dirs
            return
        end

        REXML::XPath.first(xdoc.root, "windows/prefs_dialog").each_element { |elm|
            @server = elm.attributes['params'] if elm.name == UIConsts::PREFS_ENTRY_SERVER
            @port = elm.attributes['params'].to_i if elm.name == UIConsts::PREFS_ENTRY_PORT
            @tx_block_size = elm.attributes['params'].to_i if elm.name == UIConsts::PREFS_ENTRY_BLKSIZE
            @music_dir = elm.attributes['params']+"/" if elm.name == UIConsts::PREFS_FC_MUSICDIR
            @rsrc_dir = elm.attributes['params']+"/" if elm.name == UIConsts::PREFS_FC_RSRCDIR
            @local_store = elm.attributes['params'] == 'true' if elm.name == UIConsts::PREFS_CHKBTN_LOCALSTORE
            @notifications = elm.attributes['params'] == 'true' if elm.name == UIConsts::PREFS_CB_SHOWNOTIFICATIONS
            @notif_duration = elm.attributes['params'].to_i if elm.name == UIConsts::PREFS_ENTRY_NOTIFDURATION
            @live_charts_update = elm.attributes['params'] == 'true' if elm.name == UIConsts::PREFS_CB_LIVEUPDATE
            @log_played_tracks = elm.attributes['params'] == 'true' if elm.name == UIConsts::PREFS_CB_LOGTRACKFILE
            @max_items = elm.attributes['params'].to_i if elm.name == UIConsts::PREFS_ENTRY_MAXITEMS
            @cd_device = elm.attributes['params'] if elm.name == UIConsts::PREFS_CD_DEVICE
        }
        set_dirs
        @db_version = xdoc.root.elements["database"].attributes["version"] if xdoc.root.elements["database"]
# puts "db version=#{@db_version}"
        return self
    end

    def set_local_mode
        @remote = false
    end

    def set_remote(is_remote)
        @remote = is_remote
    end

    def remote?
        return @remote
    end

    def local_store?
        return @local_store
    end

    def notifications?
        return @notifications
    end

    def notif_duration
        return @notif_duration
    end

    def set_admin_mode(is_admin)
        @admin_mode = is_admin
    end

    def admin?
        return @admin_mode
    end

    def live_charts_update?
        return @live_charts_update
    end

    def log_played_tracks?
        return @log_played_tracks
    end

    def covers_dir
        return @dirs[DIR_NAMES[0]]
    end

    def icons_dir
        return @dirs[DIR_NAMES[1]]
    end

    def flags_dir
        return @dirs[DIR_NAMES[2]]
    end

    def sources_dir
        return @dirs[DIR_NAMES[3]]
    end

    def prefs_file
        return @config_dir+PREFS_FILE
    end

    def rip_dir
        return ENV["HOME"]+"/rip/"
    end


    #
    # Special cases for the server: db & log are forced to specific directories
    #
    def database_dir
        return $0.match(/server\.rb$/) ? SERVER_RSRC_DIR+DIR_NAMES[4]+"/" : @rsrc_dir+DIR_NAMES[4]+"/"
    end

    def log_file
        return $0.match(/server\.rb$/) ? SERVER_RSRC_DIR+LOG_FILE : @rsrc_dir+LOG_FILE
    end

end

CFG = Cfg.instance.load
