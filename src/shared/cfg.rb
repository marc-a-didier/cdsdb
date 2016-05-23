
module ConfigFields
    PREFS_DIALOG                = 'prefs_dialog'

    PREFS_ENTRY_SERVER          = 'prefs_entry_server'
    PREFS_ENTRY_PORT            = 'prefs_entry_port'
    PREFS_ENTRY_BLKSIZE         = 'prefs_entry_blksize'
    PREFS_CB_SYNCCOMMS          = 'prefs_cb_synccomms'
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

    # Client/Server transmission block size
    TX_BLOCK_SIZE = 128*1024
    MSG_EOL       = 'EOL'
    FILE_INFO_SEP = '@:@'

    MSG_CONTINUE   = 'CONTINUE'
    MSG_CANCELLED  = 'CANCELLED'

    MSG_OK         = 'OK'
    MSG_DONE       = 'DONE'
    MSG_ERROR      = 'NO_METHOD'
    MSG_FUCKED     = 'CDsDB music server: Fucked up...'
    MSG_WELCOME    = 'CDsDB music server: e pericoloso sporgersi dalla finestra!'

    STAT_CONTINUE  = 1
    STAT_CANCELLED = 0

    SYNC_HDR  = '-'
    SYNC_MODE = { false => '0', true => '1' }

    class << self

        include ConfigFields

        WINDOWS = 'windows'

        CfgStorage = Struct.new(:remote, :server_mode, :admin, :config_dir,
                                :server, :port, :tx_block_size, :sync_comms, :size_over_quality,
                                :music_dir, :rsrc_dir,
                                :trace_db_cache, :trace_image_cache, :trace_gst,
                                :trace_gstqueue, :trace_network, :trace_sql,
                                :notifications, :notif_duration, :cd_device,
                                :live_charts_update, :max_items, :show_count) do
            def reload(cfg)
                self.trace_db_cache     = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_TRACEDBCACHE]['active=']
                self.trace_image_cache  = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_IMAGECACHE]['active=']
                self.trace_gst          = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_TRACEGST]['active=']
                self.trace_gstqueue     = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_TRACEGSTQUEUE]['active=']
                self.trace_network      = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_TRACENETWORK]['active=']
                self.trace_sql          = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_TRACESQLWRITES]['active=']
                self.tx_block_size      = cfg[WINDOWS][PREFS_DIALOG][PREFS_ENTRY_BLKSIZE]['text='].to_i
                self.server             = cfg[WINDOWS][PREFS_DIALOG][PREFS_ENTRY_SERVER]['text=']
                self.port               = cfg[WINDOWS][PREFS_DIALOG][PREFS_ENTRY_PORT]['text='].to_i
                self.sync_comms         = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_SYNCCOMMS]['active=']
                self.size_over_quality  = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_SIZEOVERQUALITY]['active=']
                self.music_dir          = cfg[WINDOWS][PREFS_DIALOG][PREFS_FC_MUSICDIR]["current_folder="]+'/'
                self.rsrc_dir           = cfg[WINDOWS][PREFS_DIALOG][PREFS_FC_RSRCDIR]["current_folder="]+'/'
                self.notifications      = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_SHOWNOTIFICATIONS]['active=']
                self.notif_duration     = cfg[WINDOWS][PREFS_DIALOG][PREFS_ENTRY_NOTIFDURATION]['text='].to_i
                self.live_charts_update = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_LIVEUPDATE]['active=']
                self.max_items          = cfg[WINDOWS][PREFS_DIALOG][PREFS_ENTRY_MAXITEMS]['text='].to_i
                self.show_count         = cfg[WINDOWS][PREFS_DIALOG][PREFS_CB_SHOWCOUNT]['active=']
                self.cd_device          = cfg[WINDOWS][PREFS_DIALOG][PREFS_CD_DEVICE]['text=']
                return self
            end
        end


        SERVER_RSRC_DIR = File.join(File.dirname(__FILE__), '../../')
        PREFS_FILE      = 'prefs.yml'
        LOG_FILE        = 'cdsdb.log'


        DEF_CONFIG = {  'dbversion' => '6.2',
                        WINDOWS => {
                            PREFS_DIALOG => {
                                PREFS_CB_SHOWNOTIFICATIONS => { 'active=' => true },
                                PREFS_ENTRY_NOTIFDURATION  => { 'text=' => '4' },
                                PREFS_FC_MUSICDIR          => { 'current_folder=' => ENV['HOME']+'/Music/' },
                                PREFS_FC_RSRCDIR           => { 'current_folder=' => './../../' },
                                PREFS_CD_DEVICE            => { 'text=' => '/dev/cdrom' },
                                PREFS_ENTRY_SERVER         => { 'text=' => 'madAM1H' },
                                PREFS_ENTRY_PORT           => { 'text=' => '32666' },
                                PREFS_ENTRY_BLKSIZE        => { 'text=' => '262144' },
                                PREFS_CB_SYNCCOMMS         => { 'active=' => false },
                                PREFS_CB_SIZEOVERQUALITY   => { 'active=' => false },
                                PREFS_CB_TRACEDBCACHE      => { 'active=' => false },
                                PREFS_CB_IMAGECACHE        => { 'active=' => false },
                                PREFS_CB_TRACEGST          => { 'active=' => true  },
                                PREFS_CB_TRACEGSTQUEUE     => { 'active=' => false },
                                PREFS_CB_TRACENETWORK      => { 'active=' => true  },
                                PREFS_CB_TRACESQLWRITES    => { 'active=' => false },
                                PREFS_CB_LIVEUPDATE        => { 'active=' => true  },
                                PREFS_CB_SHOWCOUNT         => { 'active=' => false },
                                PREFS_ENTRY_MAXITEMS       => { 'text=' => '100' }
                            }
                        },
                        'menus' => {}
                     }

        def load
            @cfg_store = CfgStorage.new

            dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
            @cfg_store.config_dir = File.join(dir, 'cdsdb/')
            FileUtils.mkpath(@cfg_store.config_dir) unless Dir.exists?(@cfg_store.config_dir)

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

            @cfg_store.remote = false
            @cfg_store.admin  = false
            @cfg_store.server_mode = false
        end

        def save
            @cfg_store.reload(@cfg)
            File.open(prefs_file, "w") { |file| file.puts(@cfg.to_yaml) }
        end

        def prefs_file
            return @cfg_store.config_dir+PREFS_FILE
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

        def db_version
            return @cfg['dbversion']
        end

        def set_db_version(version)
            @cfg['dbversion'] = version
        end

        def last_integrity_check
            # Stores the last date track date from logtracks on which the check log ntegrity
            # was made to restart from it rather than processing the whole db.
            # 1 is to skip never played tracks in check log
            return @cfg['last_integrity_check'] || 1
        end

        def set_last_integrity_check(date)
            @cfg['last_integrity_check'] = date
        end


        #
        # Special cases for the server: db & log are forced to specific directories
        #
        def database_dir
            return @cfg_store.server_mode ? SERVER_RSRC_DIR+'db/' : dir(:db)
        end

        def log_file
            return @cfg_store.server_mode ? SERVER_RSRC_DIR+LOG_FILE : rsrc_dir+LOG_FILE
        end
    end
end

Cfg.load
