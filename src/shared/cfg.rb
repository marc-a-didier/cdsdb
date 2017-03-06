
module ConfigFields
    PREFS_DIALOG                = 'prefs_dialog'

    PREFS_ENTRY_SERVER          = 'prefs_entry_server'
    PREFS_ENTRY_PORT            = 'prefs_entry_port'
    PREFS_ENTRY_BLKSIZE         = 'prefs_entry_blksize'
    PREFS_CB_USESSL             = 'prefs_cb_usessl'
    PREFS_CB_ASYNCCOMMS         = 'prefs_cb_asynccomms'
    PREFS_CB_SIZEOVERQUALITY    = 'prefs_cb_sizeoverquality'
    PREFS_FC_MUSICDIR           = 'prefs_fc_musicdir'
    PREFS_FC_RSRCDIR            = 'prefs_fc_rsrcdir'
    PREFS_CB_TRACEDBCACHE       = 'prefs_cb_tracedbcache'
    PREFS_CB_IMAGECACHE         = 'prefs_cb_traceimagecache'
    PREFS_CB_TRACEGST           = 'prefs_cb_tracegst'
    PREFS_CB_TRACEGSTQUEUE      = 'prefs_cb_tracegstqueue'
    PREFS_CB_TRACENETWORK       = 'prefs_cb_tracenetwork'
    PREFS_CB_TRACESQLWRITES     = 'prefs_cb_tracesqlwrites'
    PREFS_CB_SHOWNOTIFICATIONS  = 'prefs_cb_shownotifications'
    PREFS_ENTRY_NOTIFDURATION   = 'prefs_entry_notifduration'
    PREFS_CB_LIVEUPDATE         = 'prefs_cb_liveupdate'
    PREFS_ENTRY_MAXITEMS        = 'prefs_entry_maxitems'
    PREFS_CB_SHOWCOUNT          = 'prefs_cb_showcount'
    PREFS_CD_DEVICE             = 'prefs_entry_cddevice'
end

module Cfg

    VERSION = "0.10.0"

    class << self

        include ConfigFields

        WINDOWS = 'windows'

        M_ACTIVE   = 'active='
        M_TEXT     = 'text='
        M_CURR_FLD = 'current_folder='

        CfgStorage = Struct.new(:remote, :admin, :config_dir,
                                :server, :port, :tx_block_size,
                                :use_ssl, :size_over_quality, :async_comms,
                                :music_dir, :rsrc_dir,
                                :trace_db_cache, :trace_image_cache, :trace_gst,
                                :trace_gstqueue, :trace_network, :trace_sql,
                                :notifications, :notif_duration, :cd_device,
                                :live_charts_update, :max_items, :show_count) do
            def reload(cfg)
                t = cfg[WINDOWS][PREFS_DIALOG]
                self.trace_db_cache     = t[PREFS_CB_TRACEDBCACHE][M_ACTIVE]
                self.trace_image_cache  = t[PREFS_CB_IMAGECACHE][M_ACTIVE]
                self.trace_gst          = t[PREFS_CB_TRACEGST][M_ACTIVE]
                self.trace_gstqueue     = t[PREFS_CB_TRACEGSTQUEUE][M_ACTIVE]
                self.trace_network      = t[PREFS_CB_TRACENETWORK][M_ACTIVE]
                self.trace_sql          = t[PREFS_CB_TRACESQLWRITES][M_ACTIVE]
                self.tx_block_size      = t[PREFS_ENTRY_BLKSIZE][M_TEXT].to_i
                self.server             = t[PREFS_ENTRY_SERVER][M_TEXT]
                self.port               = t[PREFS_ENTRY_PORT][M_TEXT].to_i
                self.use_ssl            = t[PREFS_CB_USESSL][M_ACTIVE]
                self.async_comms        = t[PREFS_CB_ASYNCCOMMS][M_ACTIVE]
                self.size_over_quality  = t[PREFS_CB_SIZEOVERQUALITY][M_ACTIVE]
                self.music_dir          = t[PREFS_FC_MUSICDIR][M_CURR_FLD]+'/'
                self.rsrc_dir           = t[PREFS_FC_RSRCDIR][M_CURR_FLD]+'/'
                self.notifications      = t[PREFS_CB_SHOWNOTIFICATIONS][M_ACTIVE]
                self.notif_duration     = t[PREFS_ENTRY_NOTIFDURATION][M_TEXT].to_i
                self.live_charts_update = t[PREFS_CB_LIVEUPDATE][M_ACTIVE]
                self.max_items          = t[PREFS_ENTRY_MAXITEMS][M_TEXT].to_i
                self.show_count         = t[PREFS_CB_SHOWCOUNT][M_ACTIVE]
                self.cd_device          = t[PREFS_CD_DEVICE][M_TEXT]
                return self
            end
        end


        SERVER_RSRC_DIR = File.join(File.dirname(__FILE__), '../../')
        PREFS_FILE      = 'prefs.yml'
        LOG_FILE        = 'cdsdb.log'


        DEF_CONFIG = {  WINDOWS => {
                            PREFS_DIALOG => {
                                PREFS_CB_SHOWNOTIFICATIONS => { M_ACTIVE => true },
                                PREFS_ENTRY_NOTIFDURATION  => { M_TEXT => '4' },
                                PREFS_FC_MUSICDIR          => { M_CURR_FLD => ENV['HOME']+'/Music/' },
                                PREFS_FC_RSRCDIR           => { M_CURR_FLD => './../../' },
                                PREFS_CD_DEVICE            => { M_TEXT => '/dev/cdrom' },
                                PREFS_ENTRY_SERVER         => { M_TEXT => 'madAM1H' },
                                PREFS_ENTRY_PORT           => { M_TEXT => '32666' },
                                PREFS_ENTRY_BLKSIZE        => { M_TEXT => '262144' },
                                PREFS_CB_USESSL            => { M_ACTIVE => true  },
                                PREFS_CB_ASYNCCOMMS        => { M_ACTIVE => true },
                                PREFS_CB_SIZEOVERQUALITY   => { M_ACTIVE => false },
                                PREFS_CB_TRACEDBCACHE      => { M_ACTIVE => false },
                                PREFS_CB_IMAGECACHE        => { M_ACTIVE => false },
                                PREFS_CB_TRACEGST          => { M_ACTIVE => true  },
                                PREFS_CB_TRACEGSTQUEUE     => { M_ACTIVE => false },
                                PREFS_CB_TRACENETWORK      => { M_ACTIVE => true  },
                                PREFS_CB_TRACESQLWRITES    => { M_ACTIVE => false },
                                PREFS_CB_LIVEUPDATE        => { M_ACTIVE => true  },
                                PREFS_CB_SHOWCOUNT         => { M_ACTIVE => false },
                                PREFS_ENTRY_MAXITEMS       => { M_TEXT => '100' }
                            }
                        },
                        'menus' => {}
                     }

        def load
            @cfg_store = CfgStorage.new

            if ARGV[0]
                @cfg_store.config_dir = ARGV[0]
            else
                dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
                @cfg_store.config_dir = File.join(dir, 'cdsdb/')
                FileUtils.mkpath(@cfg_store.config_dir) unless Dir.exists?(@cfg_store.config_dir)
            end

            # Load preferences file
            @cfg = Psych.load_file(prefs_file) if File.exists?(prefs_file)
            if @cfg
                # If exists, add new fields from default if any
                @cfg[WINDOWS][PREFS_DIALOG].merge!(DEF_CONFIG[WINDOWS][PREFS_DIALOG]) { |key, oldval, newval| oldval ? oldval : newval }
            else
                # Start with default prefs
                @cfg = DEF_CONFIG
            end

            # Set store fields from prefs
            @cfg_store.reload(@cfg)

            # Set hostname from config if exists otherwise use real hostname
            @cfg['hostname'] = Socket.gethostname unless @cfg['hostname']

            @cfg_store.remote = false
            @cfg_store.admin  = false
        end

        def save
            @cfg_store.reload(@cfg)
            File.open(prefs_file, "w") { |file| file.puts(@cfg.to_yaml) }
        end

        def prefs_file
            return @cfg_store.config_dir+PREFS_FILE
        end

        def use_ssl?
            return @cfg_store.use_ssl
        end

        def async_comms?
            return @cfg_store.async_comms
        end

        #
        # Helpers for Prefs module
        #
        def windows
            return @cfg[WINDOWS]
        end

        def menus
            return @cfg['menus']
        end

        #
        # If we get a method_missing exception, redirect it to
        # the config store as it probably has the requested method
        #
        def method_missing(method, *args, &block)
            @cfg_store.send(method, *args, &block)
        end

        #
        # Shortcuts to avoid the method missing mechanism and improve perfs
        #
        def trace_db_cache;     return @cfg_store.trace_db_cache     end
        def trace_image_cache;  return @cfg_store.trace_image_cache  end
        def trace_gst;          return @cfg_store.trace_gst          end
        def trace_gstqueue;     return @cfg_store.trace_gstqueue     end
        def trace_network;      return @cfg_store.trace_network      end
        def trace_sql;          return @cfg_store.trace_sql          end

        #
        # Misc utilities
        #
        def remote?
            return @cfg_store.remote
        end

        def dir(type)
            return type == :track ? self.music_dir : self.rsrc_dir+type.to_s+'/'
        end

        def covers_dir;  return dir(:covers)           end
        def icons_dir;   return dir(:icons)            end
        def flags_dir;   return dir(:flags)            end
        def sources_dir; return dir(:src)              end
        def rip_dir;     return ENV['HOME']+'/rip/'    end

        def relative_path(resource_type, file)
            return file.sub(dir(resource_type), '')
        end

        def last_integrity_check
            # Stores the last track date from logtracks on which the check log integrity
            # was made to restart from it rather than processing the whole db.
            # 1 is to skip never played tracks in check log
            return @cfg['last_integrity_check'] || 1
        end

        def set_last_integrity_check(date)
            @cfg['last_integrity_check'] = date
        end

        def hostname
            return @cfg['hostname']
        end

        def database_dir
            return dir(:db)
        end

        def log_file
            return rsrc_dir+LOG_FILE
        end
    end
end

Cfg.load
