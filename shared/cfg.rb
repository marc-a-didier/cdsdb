
module ConfigFields
    PREFS_DIALOG                = "prefs_dialog"

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

        CfgStorage = Struct.new(:remote, :server_mode, :admin, :config_dir,
                                :server, :port, :tx_block_size, :music_dir, :rsrc_dir,
                                :trace_db_cache, :trace_gst, :trace_gstqueue, :trace_network,
                                :notifications, :notif_duration, :live_charts_update, :max_items, :cd_device) do
            def reload(cfg)
                self.trace_db_cache     = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEDBCACHE]["active="][0]
                self.trace_gst          = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEGST]["active="][0]
                self.trace_gstqueue     = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACEGSTQUEUE]["active="][0]
                self.trace_network      = cfg["windows"][PREFS_DIALOG][PREFS_CB_TRACENETWORK]["active="][0]
                self.tx_block_size      = cfg["windows"][PREFS_DIALOG][PREFS_ENTRY_BLKSIZE]["text="][0].to_i
                self.server             = cfg["windows"][PREFS_DIALOG][PREFS_ENTRY_SERVER]["text="][0]
                self.port               = cfg["windows"][PREFS_DIALOG][PREFS_ENTRY_PORT]["text="][0].to_i
                self.music_dir          = cfg["windows"][PREFS_DIALOG][PREFS_FC_MUSICDIR]["current_folder="][0]+"/"
                self.rsrc_dir           = cfg["windows"][PREFS_DIALOG][PREFS_FC_RSRCDIR]["current_folder="][0]+"/"
                self.notifications      = cfg["windows"][PREFS_DIALOG][PREFS_CB_SHOWNOTIFICATIONS]["active="][0]
                self.notif_duration     = cfg["windows"][PREFS_DIALOG][PREFS_ENTRY_NOTIFDURATION]["text="][0].to_i
                self.live_charts_update = cfg["windows"][PREFS_DIALOG][PREFS_CB_LIVEUPDATE]["active="][0]
                self.max_items          = cfg["windows"][PREFS_DIALOG][PREFS_ENTRY_MAXITEMS]["text="][0].to_i
                self.cd_device          = cfg["windows"][PREFS_DIALOG][PREFS_CD_DEVICE]["text="][0]
                return self
            end
        end


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
            @cfg_store = CfgStorage.new

            dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
            @cfg_store.config_dir = File.join(dir, 'cdsdb/')
            FileUtils::mkpath(@cfg_store.config_dir) unless File::exists?(@cfg_store.config_dir)

            @cfg = DEF_CONFIG
            @cfg.merge!(YAML.load_file(prefs_file)) if File.exists?(prefs_file)
            @cfg_store = CfgStorage.new.reload(@cfg)

            @cfg_store.remote = false
            @cfg_store.admin  = false
            @cfg_store.server_mode = false
p @cfg_store
#             @cfg = File.exists?(prefs_file) ? YAML.load_file(prefs_file) : DEF_CONFIG
            return self
        end

        def save
            @cfg_store.reload(@cfg)
            File.open(prefs_file, "w") { |file| file.puts(@cfg.to_yaml) }
        end

        def windows
            return @cfg["windows"]
        end

        def menus
            return @cfg["menus"]
        end
#
#         def conf
#             return @cfg["windows"][PREFS_DIALOG]
#         end
#
#         def tx_block_size;      return conf[PREFS_ENTRY_BLKSIZE]["text="][0].to_i;        end
#         def server;             return conf[PREFS_ENTRY_SERVER]["text="][0];              end
#         def port;               return conf[PREFS_ENTRY_PORT]["text="][0].to_i;           end
#         def music_dir;          return conf[PREFS_FC_MUSICDIR]["current_folder="][0]+"/"; end
#         def rsrc_dir;           return conf[PREFS_FC_RSRCDIR]["current_folder="][0]+"/";  end
#         def notifications;      return conf[PREFS_CB_SHOWNOTIFICATIONS]["active="][0];    end
#         def notif_duration;     return conf[PREFS_ENTRY_NOTIFDURATION]["text="][0].to_i;  end
#         def live_charts_update; return conf[PREFS_CB_LIVEUPDATE]["active="][0];           end
#         def max_items;          return conf[PREFS_ENTRY_MAXITEMS]["text="][0].to_i;       end
#         def cd_device;          return conf[PREFS_CD_DEVICE]["text="][0];                 end

#         def trace_db_cache;     return conf[PREFS_CB_TRACEDBCACHE]["active="][0];         end
#         def trace_gst;          return conf[PREFS_CB_TRACEGST]["active="][0];             end
#         def trace_gstqueue;     return conf[PREFS_CB_TRACEGSTQUEUE]["active="][0];        end
#         def trace_network;      return conf[PREFS_CB_TRACENETWORK]["active="][0];         end

        def trace_db_cache;     return @cfg_store.trace_db_cache  end
        def trace_gst;          return @cfg_store.trace_gst       end
        def trace_gstqueue;     return @cfg_store.trace_gstqueue  end
        def trace_network;      return @cfg_store.trace_network   end

        def method_missing(method, *args, &block)
            @cfg_store.send(method, *args, &block)
        end

        def set_local_mode
            @cfg_store.remote = false
        end

        def set_remote(is_remote)
            @cfg_store.remote = is_remote
        end

        def remote?
            return @cfg_store.remote
        end

        def dir(type);   return rsrc_dir+type.to_s+"/" end
        def covers_dir;  return dir(:covers)           end
        def icons_dir;   return dir(:icons)            end
        def flags_dir;   return dir(:flags)            end
        def sources_dir; return dir(:src)              end
        def rip_dir;     return ENV["HOME"]+"/rip/"    end

        def prefs_file
            return @cfg_store.config_dir+PREFS_FILE
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
