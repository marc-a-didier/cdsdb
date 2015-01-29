
module ConfigFields
    PREFS_DIALOG                = "prefs_dialog"

    PREFS_RB_REMOTE             = "prefs_rb_remote"
    PREFS_ENTRY_SERVER          = "prefs_entry_server"
    PREFS_ENTRY_PORT            = "prefs_entry_port"
    PREFS_ENTRY_BLKSIZE         = "prefs_entry_blksize"
    PREFS_FC_MUSICDIR           = "prefs_fc_musicdir"
    PREFS_FC_RSRCDIR            = "prefs_fc_rsrcdir"
    PREFS_CB_TRACEDBCACHE       = "prefs_cb_tracedbcache"
    PREFS_CB_TRACEGST           = "prefs_cb_tracegst"
    PREFS_CB_TRACEGSTQUEUE      = "prefs_cb_tracegstqueue"
    PREFS_CB_TRACENETWORK       = "prefs_cb_tracenetwork"
    PREFS_CB_SHOWNOTIFICATIONS  = "prefs_cb_shownotifications"
    PREFS_ENTRY_NOTIFDURATION   = "prefs_entry_notifduration"
    PREFS_CB_LIVEUPDATE         = "prefs_cb_liveupdate"
    PREFS_ENTRY_MAXITEMS        = "prefs_entry_maxitems"
    PREFS_CD_DEVICE             = "prefs_entry_cddevice"
end

module Cfg

    # Client/Server transmission block size
    TX_BLOCK_SIZE = 128*1024
    MSG_EOL       = "EOL"
    FILE_INFO_SEP = "@:@"

    MSG_CONTINUE   = "CONTINUE"
    MSG_CANCELLED  = "CANCELLED"
    STAT_CONTINUE  = 1
    STAT_CANCELLED = 0

    class << self

        include ConfigFields

#         TraceCache = Struct.new(:remote, :server, :port, :blksize, :musicdir, :rsrcdir,
#                                 :tracedbcache, :tracegst, :tracegstqueue, :tracenetwork,
#                                 :shownotif, :notifduration, :liveupdate, :maxitems, :cddevice) do
        TraceCache = Struct.new(:trace_db_cache, :trace_gst, :trace_gstqueue, :trace_network) do
            def reload(cfg)
                self.trace_db_cache = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEDBCACHE]["active="][0]
                self.trace_gst      = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEGST]["active="][0]
                self.trace_gstqueue = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEGSTQUEUE]["active="][0]
                self.trace_network  = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACENETWORK]["active="][0]
                return self
            end
        end


        attr_accessor :server_mode

        SERVER_RSRC_DIR = "../../"
        PREFS_FILE      = "prefs.yml"
        LOG_FILE        = "cdsdb.log"


        DEF_CONFIG = {  "dbversion" => "6.0",
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
                                PREFS_CB_TRACEDBCACHE      => { "active=" => [false] },
                                PREFS_CB_TRACEGST          => { "active=" => [true]  },
                                PREFS_CB_TRACEGSTQUEUE     => { "active=" => [false] },
                                PREFS_CB_TRACENETWORK      => { "active=" => [true]  },
                                PREFS_CB_LIVEUPDATE        => { "active=" => [true]  },
                                PREFS_ENTRY_MAXITEMS       => { "text=" => ["100"] }
                            }
                        },
                        "menus" => {}
                     }

        def load
            dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
            @config_dir = File.join(dir, 'cdsdb/')
            FileUtils::mkpath(@config_dir) unless File::exists?(@config_dir)

            @remote = false
            @admin_mode = false
            @server_mode = false

            @cfg = DEF_CONFIG
            @cfg.merge!(YAML.load_file(prefs_file)) if File.exists?(prefs_file)
            @trace_cache = TraceCache.new.reload(@cfg)
p @trace_cache
#             @cfg = File.exists?(prefs_file) ? YAML.load_file(prefs_file) : DEF_CONFIG
            return self
        end

        def save
            @trace_cache.reload(@cfg)
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
        def notifications;      return conf[PREFS_CB_SHOWNOTIFICATIONS]["active="][0];    end
        def notif_duration;     return conf[PREFS_ENTRY_NOTIFDURATION]["text="][0].to_i;  end
        def live_charts_update; return conf[PREFS_CB_LIVEUPDATE]["active="][0];           end
        def max_items;          return conf[PREFS_ENTRY_MAXITEMS]["text="][0].to_i;       end
        def cd_device;          return conf[PREFS_CD_DEVICE]["text="][0];                 end

#         def trace_db_cache;     return conf[PREFS_CB_TRACEDBCACHE]["active="][0];         end
#         def trace_gst;          return conf[PREFS_CB_TRACEGST]["active="][0];             end
#         def trace_gstqueue;     return conf[PREFS_CB_TRACEGSTQUEUE]["active="][0];        end
#         def trace_network;      return conf[PREFS_CB_TRACENETWORK]["active="][0];         end

        def trace_db_cache;     return @trace_cache.trace_db_cache  end
        def trace_gst;          return @trace_cache.trace_gst       end
        def trace_gstqueue;     return @trace_cache.trace_gstqueue  end
        def trace_network;      return @trace_cache.trace_network   end

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
end

Cfg.load
