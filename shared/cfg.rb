
class Cfg

    include Singleton
    include UIConsts

    attr_accessor :server_mode

    # Client/Server transmission block size
    TX_BLOCK_SIZE = 128*1024
    MSG_EOL       = "EOL"
    FILE_INFO_SEP = "@:@"

    MSG_CONTINUE   = "CONTINUE"
    MSG_CANCELLED  = "CANCELLED"
    STAT_CONTINUE  = 1
    STAT_CANCELLED = 0

    DIRS            = [:covers, :icons, :flags, :src, :db]
    SERVER_RSRC_DIR = "../../"
    PREFS_FILE      = "prefs.yml"
    LOG_FILE        = "cdsdb.log"


    DEF_CONFIG = { "dbversion" => "6.0",
                   "windows" => {
                        PREFS_DIALOG => {
                            PREFS_CB_SHOWNOTIFICATIONS => { "active=" => [true] },
                            PREFS_ENTRY_NOTIFDURATION  => { "text=" => ["4"] },
                            PREFS_FC_MUSICDIR          => { "current_folder=" => [ENV['HOME']+"/Music/"] },
                            PREFS_FC_RSRCDIR           => { "current_folder=" => ["./../../"] },
                            PREFS_CD_DEVICE            => { "text=" => ["/dev/cdrom"] },
                            PREFS_ENTRY_SERVER         => { "text=" => ["madd510"] },
                            PREFS_ENTRY_PORT           => { "text=" => ["32666"] },
                            PREFS_ENTRY_BLKSIZE        => { "text=" => ["262144"] },
                            PREFS_CHKBTN_LOCALSTORE    => { "active=" => [true] },
                            PREFS_CB_LIVEUPDATE        => { "active=" => [true] },
                            PREFS_CB_LOGTRACKFILE      => { "active=" => [false] },
                            PREFS_ENTRY_MAXITEMS       => { "text=" => ["100"] }
                        }
                   },
                   "menus" => {}
                 }

    def initialize
        dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
        @config_dir = File.join(dir, 'cdsdb/')
        FileUtils::mkpath(@config_dir) unless File::exists?(@config_dir)

        @remote = false
        @admin_mode = false
        @server_mode = false
    end

    def load
        @cfg = File.exists?(prefs_file) ? YAML.load_file(prefs_file) : DEF_CONFIG.clone
        return self
    end

    def save
        File.open(prefs_file, "w") { |file| file.puts(@cfg.to_yaml) }
    end

    def windows
        return @cfg["windows"]
    end

    def menus
        return @cfg["menus"]
    end

    def conf
        return @cfg["windows"][PREFS_DIALOG]
    end

    def tx_block_size;      return conf[PREFS_ENTRY_BLKSIZE]["text="][0].to_i;        end
    def server;             return conf[PREFS_ENTRY_SERVER]["text="][0];              end
    def port;               return conf[PREFS_ENTRY_PORT]["text="][0].to_i;           end
    def music_dir;          return conf[PREFS_FC_MUSICDIR]["current_folder="][0]+"/"; end
    def rsrc_dir;           return conf[PREFS_FC_RSRCDIR]["current_folder="][0]+"/";  end
    def local_store;        return conf[PREFS_CHKBTN_LOCALSTORE]["active="][0];       end
    def notifications;      return conf[PREFS_CB_SHOWNOTIFICATIONS]["active="][0];    end
    def notif_duration;     return conf[PREFS_ENTRY_NOTIFDURATION]["text="][0].to_i;  end
    def live_charts_update; return conf[PREFS_CB_LIVEUPDATE]["active="][0];           end
    def log_played_tracks;  return conf[PREFS_CB_LOGTRACKFILE]["active="][0];         end
    def max_items;          return conf[PREFS_ENTRY_MAXITEMS]["text="][0].to_i;       end
    def cd_device;          return conf[PREFS_CD_DEVICE]["text="][0];                 end

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
        return local_store
    end

    def notifications?
        return notifications
    end

    def live_charts_update?
        return live_charts_update
    end

    def log_played_tracks?
        return log_played_tracks
    end

    def set_admin_mode(is_admin)
        @admin_mode = is_admin
    end

    def admin?
        return @admin_mode
    end

    def covers_dir
        return dir(:covers)
    end

    def icons_dir
        return dir(:icons)
    end

    def flags_dir
        return dir(:flags)
    end

    def sources_dir
        return dir(:src)
    end

    def prefs_file
        return @config_dir+PREFS_FILE
    end

    def rip_dir
        return ENV["HOME"]+"/rip/"
    end

    def dir(type)
        return rsrc_dir+type.to_s+"/"
    end

    def db_version
        return @cfg["dbversion"]
    end

    def set_db_version(version)
        @cfg["dbversion"] = version
    end

    #
    # Special cases for the server: db & log are forced to specific directories
    #
    def database_dir
        return $0.match(/server\.rb$/) ? SERVER_RSRC_DIR+"db/" : dir(:db)
    end

    def log_file
        return $0.match(/server\.rb$/) ? SERVER_RSRC_DIR+LOG_FILE : rsrc_dir+LOG_FILE
    end

end

CFG = Cfg.instance.load
