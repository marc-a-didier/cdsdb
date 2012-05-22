# encoding: utf-8

module UIConsts


    #
    # Glade related consts
    #
    GLADE_MAIN          = "../glade/cdsdb.glade"
    GLADE_DIALOGS       = "../glade/dialogs.glade"
    GLADE_DOMAIN        = "cdsdb"

    # Windows

    MAIN_WINDOW             = "main_window"



    # Treeviews
    ARTISTS_TREEVIEW    = "tva"
    RECORDS_TREEVIEW    = "tvr"
    TRACKS_TREEVIEW     = "tvt"


    # Main window tool bar
    MW_TOOLBAR          = "mw_toolbar"

    # Main window expander
    MW_EXPANDER         = "mw_expander"

    # Main window notebook
    NB_NOTEBOOK         = "notebook"

    # Main windows toggle actions
    MW_PLAYER_ACTION    = "mw_player_action"
    MW_PQUEUE_ACTION    = "mw_pqueue_action"
    MW_PLISTS_ACTION    = "mw_plists_action"
    MW_CHARTS_ACTION    = "mw_charts_action"
    MW_TASKS_ACTION     = "mw_tasks_action"
    MW_FILTER_ACTION    = "mw_filter_action"
    MW_MEMOS_ACTION     = "mw_memos_action"
    MW_MEMO_SAVE_ACTION = "mw_memo_save_action"
#     MW_APPFILTER_ACTION = "mw_appfilter_action"

    #
    # Main window browser infos bars
    MW_INFLBL_ARTIST    = "mw_inflbl_artist"
    MW_INFLBL_RECORD    = "mw_inflbl_record"
    MW_INFLBL_TRACK     = "mw_inflbl_track"
    
    
    # Record tab entries
    #ENTRY_CDID          = "rec_entry_cddbid"
#     ENTRY_YEAR          = "rec_tab_entry_iyear"
#     ENTRY_REFERENCE     = "rec_tab_entry_scatalog"
#     ENTRY_LABEL         = "rec_tab_lkentry_rlabel"
#     ENTRY_SETNO         = "rec_tab_entry_isetorder"
#     ENTRY_SETOF         = "rec_tab_entry_isetof"
#     ENTRY_COLLECTION    = "rec_tab_lkentry_rcollection"
#     ENTRY_GENRE         = "rec_tab_lkentry_rgenre"
#     ENTRY_ARTIST        = "rec_tab_lkentry_rartist"
#     ENTRY_TITLE         = "rec_tab_entry_stitle"
#     ENTRY_RECDURATION   = "rec_tab_timeentry_iplaytime"
#     ENTRY_REC_MEDIA     = "rec_tab_lkentry_rmedia"
#     TEXTVIEW_RECORD     = "rec_tab_txtview_mnotes"
#     CB_SET              = "rec_tab_cb_iisinset"
#     REC_BTN_ARTIST      = "rec_tab_btn_artist"
#     REC_BTN_LABEL       = "rec_tab_btn_label"
#     REC_BTN_GENRE       = "rec_tab_btn_genre"
#     REC_BTN_COLLECTION  = "rec_tab_btn_collection"
#     REC_BTN_PLAYHISTORY = "rec_tab_btn_playhistory"
    REC_IMAGE           = "rec_image"
    REC_VP_IMAGE        = "rec_vp_image"


    # Segment tab entries
#     ENTRY_NOINDEX       = "seg_tab_entry_iorder"
#     ENTRY_SEGTITLE      = "seg_tab_entry_stitle"
#     ENTRY_IXDURATION    = "seg_tab_timeentry_iplaytime"
#     ENTRY_IXARTIST      = "seg_tab_lkentry_rartist"
#     TEXTVIEW_SEGMENT    = "seg_tab_txtview_mnotes"
#     SEG_BTN_ARTIST      = "seg_tab_btn_artist"


    # Track tab entries
#     ENTRY_TRACKNO         = "trk_tab_entry_iorder"
#     ENTRY_TRACKTITLE      = "trk_tab_entry_stitle"
#     ENTRY_TRACKLEN        = "trk_tab_timeentry_iplaytime"
#     ENTRY_TRACKPLAYCOUNT  = "trk_tab_entry_iplayed"
#     ENTRY_TRACKLASTPLAYED = "trk_tab_dateentry_ilastplayed"
#     TRK_CMB_RATING        = "trk_tab_cmb_irating"
#     TEXTVIEW_TRACK        = "trk_tab_txtview_mnotes"
#     TRK_BTN_AUDIOFILE     = "trk_tab_btn_audiofile"
#     TRK_BTN_PLAYHISTORY   = "trk_tab_btn_playhistory"
#     TRK_BTN_PLAYLISTS     = "trk_tab_btn_playlists"
#     TRK_TV_TAGS           = "trk_tab_tv_itags"


    # Artist tab entries
#     ENTRY_ARTARTIST       = "art_tab_entry_rartist"
#     ENTRY_ARTORIGIN       = "art_tab_lkentry_rorigin"
#     ENTRY_ARTWEBSITE      = "art_tab_entry_swebsite"
#     ENTRY_ARTREFART       = "art_tab_entry_sref"
#     TEXTVIEW_ARTIST       = "art_tab_txtview_mnotes"
#     ART_BTN_ORIGIN        = "art_tab_btn_origin"


    # Artists browser popup menu
    ART_POPUP_MENU      = "apm_menu"
    ART_POPUP_ADD       = "apm_add"
    ART_POPUP_DEL       = "apm_del"
    ART_POPUP_EDIT      = "apm_edit"
#     ART_POPUP_VIEWALL   = "apm_view_all"
#     ART_POPUP_VIEWRECS  = "apm_view_by_records"
#     ART_POPUP_FILTER    = "apm_filter"
#     ART_POPUP_FILTERCLR = "apm_clear_filter"

    # Records/Segments browser popup menu
    REC_POPUP_MENU      = "rpm_menu"
    REC_POPUP_EDIT      = "rpm_edit"
    REC_POPUP_ADD       = "rpm_add"
    REC_POPUP_DEL       = "rpm_del"
    REC_POPUP_SEGADD    = "rpm_seg_add"
    REC_POPUP_CPTITLE   = "rpm_cp_title"
    REC_POPUP_TAGDIR    = "rpm_tag_dir"
    REC_POPUP_ENQUEUE   = "rpm_enqueue"
    REC_POPUP_SEGORDER  = "rpm_set_seg_order"
    REC_POPUP_RATING    = "rpm_rating"
    REC_POPUP_TAGS      = "rpm_tags"
    REC_POPUP_PHISTORY  = "rpm_phistory"
    REC_POPUP_DOWNLOAD  = "rpm_download"

    # Tracks browser popup menu
    TRK_POPUP_MENU      = "tpm_menu"
    TRK_POPUP_EDIT      = "tpm_edit"
    TRK_POPUP_ADD       = "tpm_add"
    TRK_POPUP_DEL       = "tpm_del"
    TRK_POPUP_DELFROMFS = "tpm_del_from_fs"
    TRK_POPUP_DOWNLOAD  = "tpm_download"
    TRK_POPUP_TAGFILE   = "tpm_tag_file"
    TRK_POPUP_UPDPTIME  = "tpm_upd_ptime"
    TRK_POPUP_ENQUEUE   = "tpm_enqueue"
    TRK_POPUP_ENQFROM   = "tpm_enqueue_from"
    TRK_POPUP_SEGASS    = "tpm_seg_ass"
    TRK_POPUP_ADDTOPL   = "tpm_add_to_pl"
    TRK_POPUP_RATING    = "tpm_rating"
    TRK_POPUP_TAGS      = "tpm_tags"
    TRK_POPUP_AUDIOINFO = "tpm_audioinfo"
    TRK_POPUP_PLAYHIST  = "tpm_playhist"
    TRK_POPUP_CONTPL    = "tpm_contpl"

    # Status icon popup menu
    TTPM_MENU       = "ttpm_menu"
    TTPM_ITEM_PLAY  = "ttpm_item_play"
    TTPM_ITEM_PAUSE = "ttpm_item_pause"
    TTPM_ITEM_STOP  = "ttpm_item_stop"
    TTPM_ITEM_PREV  = "ttpm_item_prev"
    TTPM_ITEM_NEXT  = "ttpm_item_next"
    TTPM_ITEM_QUIT  = "ttpm_item_quit"


    # Application main menu

    # File menu
    MM_FILE_CHECKCD             = "mm_file_checkcd"
    MM_FILE_IMPORTSQL           = "mm_file_importsql"
    MM_FILE_IMPORTAUDIO         = "mm_file_importaudio"
    MM_FILE_SAVE                = "mm_file_save"
    MM_FILE_QUIT                = "mm_file_quit"

    # Edit menu
    MM_EDIT_SEARCH              = "mm_edit_search"
    MM_EDIT_PREFS               = "mm_edit_prefs"

    # View menu
    VIEW_MENU                   = "view_menu"
    MM_VIEW_AUTOCHECK           = "mm_view_autocheck"
    MM_VIEW_TRACKINDEX          = "mm_view_trackindex"
    MM_VIEW_SEGTITLE            = "mm_view_segtitle"
    MM_VIEW_BYRATING            = "mm_view_byrating"
#     MM_VIEW_FILTER              = "mm_view_filter"
    MM_VIEW_COMPILE             = "mm_view_compile"
    MM_VIEW_DBREFS              = "mm_view_dbrefs"

    # Windows menus
    MM_WIN_MENU                 = "win_menu"
    MM_WIN_PLAYER               = "mm_win_player"
    MM_WIN_PLAYQUEUE            = "mm_win_playqueue"
    MM_WIN_PLAYLISTS            = "mm_win_playlists"
    MM_WIN_CHARTS               = "mm_win_charts"
    MM_WIN_FILTER               = "mm_win_filter"
    MM_WIN_TASKS                = "mm_win_tasks"
    MM_WIN_MEMOS                = "mm_win_memos"
    MM_WIN_RECENT               = "mm_win_recent"
    MM_WIN_RIPPED               = "mm_win_ripped"
    MM_WIN_PLAYED               = "mm_win_played"
    MM_WIN_OLDEST               = "mm_win_oldest"

    # Tools menu
    MM_TOOLS_TAG_GENRE          = "mm_tools_tag_genre"
    MM_TOOLS_SEARCH_ORPHANS     = "mm_tools_search_orphans"
    MM_TOOLS_SCANAUDIO          = "mm_tools_scanaudio"
    MM_TOOLS_IMPORTPLAYEDTRACKS = "mm_tools_importplayedtracks"
    MM_TOOLS_SYNCSRC            = "mm_tools_syncsrc"
    MM_TOOLS_SYNCDB             = "mm_tools_syncdb"
    MM_TOOLS_SYNCRES            = "mm_tools_syncres"
    MM_TOOLS_EXPORTDB           = "mm_tools_exportdb"
    MM_TOOLS_GENREORDER		    = "mm_tools_genreorder"
    MM_TOOLS_RATINGSTEST	    = "mm_tools_testratings"
    MM_TOOLS_FULLSTATS          = "mm_tools_fullstats"
    MM_TOOLS_DBSTATS            = "mm_tools_dbstats"
    MM_TOOLS_CHARTS             = "mm_tools_charts"
    MM_TOOLS_PLAYHISTORY        = "mm_tools_playhistory"
    MM_TOOLS_RATINGS            = "mm_tools_ratings"

    # About menu
    MM_ABOUT                    = "about_imagemenuitem"



    # Toolbars buttons

    MW_TBBTN_APPFILTER  = "mw_tbbtn_appfilter"
    MW_TBBTN_TASKS      = "mw_tbbtn_tasks"
    MW_TBBTN_FILTER     = "mw_tbbtn_filter"
    MW_TBBTN_MEMOS      = "mw_tbbtn_memos"

    MW_TBBTN_PLAYER = "mw_tbbtn_player"
    MW_TBBTN_PQUEUE = "mw_tbbtn_pqueue"
    MW_TBBTN_PLISTS = "mw_tbbtn_plists"
    MW_TBBTN_CHARTS = "mw_tbbtn_charts"


    #
    # Memos window controls
    #
    MEMO_NBOOK  =   "memo_nbook"
    


    #
    # Player window controls
    #
    PLAYER_WINDOW           = "player_window"

    PLAYER_BTN_START        = "player_btn_start"
    PLAYER_BTN_STOP         = "player_btn_stop"
    PLAYER_BTN_NEXT         = "player_btn_next"
    PLAYER_BTN_PREV         = "player_btn_prev"
    PLAYER_HSCALE           = "player_hscale"
    PLAYER_PB_LEFT          = "player_pb_left"
    PLAYER_PB_RIGHT         = "player_pb_right"
    PLAYER_LABEL_TITLE      = "player_label_title"
    PLAYER_LABEL_DURATION   = "player_label_duration"
    PLAYER_LABEL_POS        = "player_label_pos"
    PLAYER_BTN_SWITCH       = "player_btn_switch"

    #
    # Export dialog controls
    #
    EXPORT_DEVICE_DIALOG    = "export_device_dialog"

    EXP_DLG_FC_SOURCE       = "exp_dlg_fc_source"
    EXP_DLG_FC_DEST         = "exp_dlg_fc_dest"
    EXP_DLG_CB_RMGENRE      = "exp_dlg_cb_rmgenre"
    EXP_DLG_CB_FATCOMPAT    = "exp_dlg_cb_fatcompat"

    #
    # Generic DB selector dialog
    #
    DBSEL_DIALOG        = "db_selector_dialog"
    DBSEL_TBBTN_ADD     = "dbsel_tbbtn_add"
    DBSEL_TBBTN_EDIT    = "dbsel_tbbtn_edit"
    DBSEL_TBBTN_DELETE  = "dbsel_tbbtn_delete"
    DBSEL_TV            = "dbsel_tv"

    #
    # Recent tracks dialog
    #
    RECENT_TRACKS_DIALOG    = "recent_tracks_dialog"
    RECTRACKS_BTN_SHOW      = "rectracks_btn_show"
    RECTRACKS_TV            = "rectracks_tv"

    #
    # Recent added/ripped records dialog
    #
    RECENT_RECORDS_DIALOG   = "recent_records_dialog"
    RECREC_BTN_SHOW         = "recrec_btn_show"
    RECREC_BTN_CLOSE        = "recrec_btn_close"
    RECREC_TV               = "recrec_tv"

    #
    # Play history dialog
    #
    PLAY_HISTORY_DIALOG = "play_history_dialog"
    PH_TV               = "ph_tv"
    PH_CHARTS_LBL       = "tph_lbl_charts"
    
    #
    # Track play list dialog
    #
    TRK_PLISTS_DIALOG   = "trk_plists_dialog"
    TRK_PLISTS_BTN_SHOW = "trk_plists_btn_show"
    TRK_PLISTS_TV       = "trk_plists_tv"

    #
    # CDEditor window controls
    #
    CD_EDITOR_WINDOW    = "cd_editor_window"
    CDED_TV             = "cded_tv"
    CDED_BTN_CP_ARTIST  = "cded_btn_cp_artist"
    CDED_BTN_CP_TITLE   = "cded_btn_cp_title"
    CDED_BTN_GENSQL     = "cded_btn_gensql"
    CDED_BTN_CLOSE      = "cded_btn_close"
    CDED_BTN_SWAP       = "cded_btn_swap"
    CDED_ENTRY_ARTIST   = "cded_entry_artist"
    CDED_ENTRY_TITLE    = "cded_entry_title"
    CDED_ENTRY_GENRE    = "cded_entry_genre"
    CDED_ENTRY_YEAR     = "cded_entry_year"

    #
    # Search dialog
    #
    SEARCH_DIALOG       = "search_dialog"
    SRCH_DLG_BTN_SEARCH = "srch_dlg_btn_search"
    SRCH_DLG_BTN_SHOW   = "srch_dlg_btn_show"
    SRCH_DLG_TV         = "srch_dlg_tv"
    SRCH_DLG_RB_TRACK   = "srch_dlg_rb_track"
    SRCH_DLG_RB_LYRICS  = "srch_dlg_rb_lyrics"
    SRCH_DLG_RB_REC     = "srch_dlg_rb_rec"
    SRCH_DLG_RB_SEG     = "srch_dlg_rb_seg"
    SRCH_ENTRY_TEXT     = "srch_entry_text"

    #
    # Prefs dialogs
    #
    PREFS_DIALOG                = "prefs_dialog"

    PREFS_RB_REMOTE             = "prefs_rb_remote"
    PREFS_ENTRY_SERVER          = "prefs_entry_server"
    PREFS_ENTRY_PORT            = "prefs_entry_port"
    PREFS_ENTRY_BLKSIZE         = "prefs_entry_blksize"
    PREFS_FC_MUSICDIR           = "prefs_fc_musicdir"
    PREFS_FC_RSRCDIR            = "prefs_fc_rsrcdir"
    PREFS_CHKBTN_LOCALSTORE     = "prefs_chkbtn_localstore"
    PREFS_CB_SHOWNOTIFICATIONS  = "prefs_cb_shownotifications"
    PREFS_ENTRY_NOTIFDURATION   = "prefs_entry_notifduration"
    PREFS_CB_LIVEUPDATE         = "prefs_cb_liveupdate"
    PREFS_CB_LOGTRACKFILE       = "prefs_cb_logtrackfile"
#     PREFS_CHKBTN_SYNCDLS        = "prefs_chkbtn_syncdls"
    PREFS_ENTRY_MAXITEMS        = "prefs_entry_maxitems"
#     PREFS_CB_SYSRAND            = "prefs_cb_sysrandom"
    PREFS_CD_DEVICE             = "prefs_entry_cddevice"

    #
    # Play lists window
    #
    PLISTS_WINDOW       = "plists_window"
    PM_PL               = "pm_pl"
    PM_PL_SAVE          = "pm_pl_save"
    PM_PL_ADD           = "pm_pl_add"
    PM_PL_DELETE        = "pm_pl_delete"
    PM_PL_INFOS         = "pm_pl_infos"
    PM_PL_EXPORT_XSPF   = "pm_pl_export_xspf"
    PM_PL_EXPORT_M3U    = "pm_pl_export_m3u"
    PM_PL_EXPORT_PLS    = "pm_pl_export_pls"
    PM_PL_EXPORT_DEVICE = "pm_pl_export_device"
    PM_PL_SHUFFLE       = "pm_pl_shuffle"
    PM_PL_ENQUEUE       = "pm_pl_enqueue"
    PM_PL_SHOWINBROWSER = "pm_pl_showinbrowser"

    PL_MB_NEW           = "pl_mb_new"
    PL_MB_SAVE          = "pl_mb_save"
    PL_MB_DELETE        = "pl_mb_delete"
    PL_MB_INFOS         = "pl_mb_infos"
#     PL_MB_GENERATE      = "pl_mb_generate"
    PL_MB_EXPORT_XSPF   = "pl_mb_export_xspf"
    PL_MB_EXPORT_M3U    = "pl_mb_export_m3u"
    PL_MB_EXPORT_PLS    = "pl_mb_export_pls"
    PL_MB_EXPORT_DEVICE = "pl_mb_export_device"
    PL_MB_CLOSE         = "pl_mb_close"
    PL_MB_SHUFFLE       = "pl_mb_shuffle"
    PL_MB_RENUMBER      = "pl_mb_renumber"
    PL_MB_CHKORPHAN     = "pl_mb_chkorphan"

    TV_PLISTS           = "tv_plists"
    TV_PLTRACKS         = "tv_pltracks"

    PL_LBL_TRACKS       = "pl_lbl_tracks"
    PL_LBL_PTIME        = "pl_lbl_ptime"
    PL_LBL_ETA          = "pl_lbl_eta"

    DLG_PLIST_INFOS     = "dlg_plist_infos"

    #
    # Play queue window
    #
    PQUEUE_WINDOW       = "pqueue_window"
    PM_PQ               = "pm_pq"
    PM_PQ_REMOVE        = "pm_pq_remove"
    PM_PQ_RMFROMHERE    = "pm_pq_rmfromhere"
    PM_PQ_CLEAR         = "pm_pq_clear"
    PM_PQ_SHOWINBROWSER = "pm_pq_showinbrowser"
    PM_PQ_SHUFFLE       = "pm_pq_shuffle"

    SCROLLEDWINDOW_PQUEUE   = "scrolledwindow_pqueue"
    TV_PQUEUE               = "tv_pqueue"

    PQ_LBL_TRACKS       = "pq_lbl_tracks"
    PQ_LBL_PTIME        = "pq_lbl_ptime"
    PQ_LBL_ETA          = "pq_lbl_eta"

    #
    # Multi choice db selector dialog
    #
    MCDB_DIALOG         = "mcdb_select_dialog"
    MCDB_TV             = "mcdb_tv"

    #
    # Filter generator dialog
    #
#     FILTER_GENERATOR_DIALOG = "filter_generator_dialog"
# 
#     FLTGEN_TV_TAGS          = "fltgen_tv_tags"
# 
#     HS_PLAYED_WEIGHT        = "fltgen_hs_playedweight"
#     LBL_PLAYED_WEIGHT       = "fltgen_lbl_val_playedweight"
#     HS_MIN_PLAYED           = "fltgen_hs_minplayed"
#     LBL_MIN_PLAYED          = "fltgen_lbl_val_minplayed"
#     HS_MAX_PLAYED           = "fltgen_hs_maxplayed"
#     LBL_MAX_PLAYED          = "fltgen_lbl_val_maxplayed"
# 
#     HS_RATING_WEIGHT        = "fltgen_hs_ratingweight"
#     LBL_RATING_WEIGHT       = "fltgen_lbl_val_ratingweight"
#     HS_MIN_RATING           = "fltgen_hs_minrating"
#     LBL_MIN_RATING          = "fltgen_lbl_val_minrating"
#     HS_MAX_RATING           = "fltgen_hs_maxrating"
#     LBL_MAX_RATING          = "fltgen_lbl_val_maxrating"
# 
#     HS_MIN_DURATION         = "fltgen_hs_minduration"
#     LBL_MIN_DURATION        = "fltgen_lbl_val_minduration"
#     HS_MAX_DURATION         = "fltgen_hs_maxduration"
#     LBL_MAX_DURATION        = "fltgen_lbl_val_maxduration"
# 
#     FLTGEN_LBL_GENRES       = "fltgen_lbl_genres"
#     FLTGEN_LBL_COUNTRIES    = "fltgen_lbl_countries"
#     FLTGEN_LBL_LABELS       = "fltgen_lbl_labels"
#     FLTGEN_LBL_MEDIA        = "fltgen_lbl_media"
# 
#     FLTGEN_BTN_GENRES       = "fltgen_btn_genres"
#     FLTGEN_BTN_COUNTRIES    = "fltgen_btn_countries"
#     FLTGEN_BTN_LABELS       = "fltgen_btn_labels"
#     FLTGEN_BTN_MEDIA        = "fltgen_btn_media"
# 
#     FLTGEN_CMB_SELECTBY     = "fltgen_cmb_selectby"
#     FLTGEN_CB_PLAYED        = "fltgen_cb_played"
#     FLTGEN_CB_RATING        = "fltgen_cb_rating"
#     FLTGEN_CB_MATCHALL      = "fltgen_cb_matchall"
#     FLTGEN_SB_MAXENTRIES    = "fltgen_sb_maxentries"
# 
#     FLTGEN_CHK_FROMDATE		= "fltgen_chk_fromdate"
# 	FLTGEN_ENTRY_FROMDATE	= "fltgen_entry_fromdate"
# 	FLTGEN_BTN_FROMDATE		= "fltgen_btn_fromdate"
#     FLTGEN_CHK_TODATE		= "fltgen_chk_todate"
# 	FLTGEN_ENTRY_TODATE		= "fltgen_entry_todate"
# 	FLTGEN_BTN_TODATE		= "fltgen_btn_todate"


    #
    # Charts window
    #
    CHARTS_WINDOW           = "charts_window"

    CHARTS_TV               = "charts_tv"
    CHARTS_MM_TRACKS        = "charts_mm_tracks"
    CHARTS_MM_RECORDS       = "charts_mm_records"
    CHARTS_MM_ARTISTS       = "charts_mm_artists"
    CHARTS_MM_MTYPES        = "charts_mm_mtypes"
    CHARTS_MM_LABELS        = "charts_mm_labels"
    CHARTS_MM_COUNTRIES     = "charts_mm_countries"
    CHARTS_MM_PLAYED        = "charts_mm_played"
    CHARTS_MM_TIME          = "charts_mm_time"
#     CHARTS_MM_FILTER        = "charts_mm_filter"
#     CHARTS_MM_CLEAR_FILTER  = "charts_mm_clear_filter"
    CHARTS_MM_CLOSE         = "charts_mm_close"

    CHARTS_PM               = "charts_pm"
    CHARTS_PM_ENQUEUE       = "charts_pm_enqueue"
    CHARTS_PM_ENQUEUEFROM   = "charts_pm_enqueuefrom"
    CHARTS_PM_PLAYHISTORY   = "charts_pm_playhistory"
    CHARTS_PM_GENPL         = "charts_pm_genpl"
    CHARTS_PM_SHOWINDB      = "charts_pm_showindb"

    #
    # Audio dialog
    #
    AUDIO_DIALOG        = "audio_dialog"
    AUDIO_ENTRY_FILE    = "audio_entry_file"
    AUDIO_LBL_DFILESIZE = "audio_lbl_dfilesize"
    AUDIO_LBL_DTITLE    = "audio_lbl_dtitle"
    AUDIO_LBL_DARTIST   = "audio_lbl_dartist"
    AUDIO_LBL_DALBUM    = "audio_lbl_dalbum"
    AUDIO_LBL_DTRACK    = "audio_lbl_dtrack"
    AUDIO_LBL_DYEAR     = "audio_lbl_dyear"
    AUDIO_LBL_DDURATION = "audio_lbl_dduration"
    AUDIO_LBL_DGENRE    = "audio_lbl_dgenre"
    AUDIO_ENTRY_COMMENT = "audio_entry_comment"

    AUDIO_LBL_DCODEC        = "audio_lbl_dcodec"
    AUDIO_LBL_DCHANNELS     = "audio_lbl_dchannels"
    AUDIO_LBL_DSAMPLERATE   = "audio_lbl_dsamplerate"
    AUDIO_LBL_DBITRATE      = "audio_lbl_dbitrate"


    #
    # Tasks window
    #
    TASKS_WINDOW    = "tasks_window"
    TASKS_TV        = "tasks_tv"
    # Tasks poopup menu
    TASKS_POPUP_MENU    = "tasks_pm"
    TKPM_CLEAR          = "tkpm_clear"
    TKPM_CLOSE          = "tkpm_close"

    #
    # Memos window
    #
    MEMOS_WINDOW    = "memos_window"

    #
    # Database editor
    #
    DLG_DB_EDITOR   = "dlg_db_editor"
    DBED_NBOOK      = "dbed_nbook"
    DBED_BTN_OK     = "dbed_btn_ok"
    DBED_BTN_CANCEL = "dbed_btn_cancel"
    

    #
    # Artist editor dialog
    #
    DLG_ART_EDITOR      = "dlg_art_editor"

    ARTED_ENTRY_ARTIST  = "arted_entry_sname"
    ARTED_ENTRY_WEBSITE = "arted_entry_swebsite"
    ARTED_ENTRY_ORIGIN  = "arted_entry_rorigin"
    ARTED_ENTRY_DBREF   = "arted_entry_rartist"

    ARTED_BTN_ORIGIN    = "arted_btn_origin"

    ARTED_BTN_OK        = "arted_btn_ok"
    ARTED_BTN_CANCEL    = "arted_btn_cancel"


    #
    # Record editor dialog
    #
    DLG_REC_EDITOR          = "dlg_rec_editor"

    RECED_ENTRY_ARTIST      = "reced_lkentry_rartist"
    RECED_ENTRY_TITLE       = "reced_entry_stitle"
    RECED_ENTRY_YEAR        = "reced_entry_iyear"
    RECED_ENTRY_GENRE       = "reced_lkentry_rgenre"
    RECED_ENTRY_PTIME       = "reced_timeentry_iplaytime"
    RECED_ENTRY_LABEL       = "reced_lkentry_rlabel"
    RECED_ENTRY_CAT         = "reced_entry_scatalog"
    RECED_ENTRY_CDDBID      = "reced_entry_icddbid"
    RECED_ENTRY_MEDIUM      = "reced_lkentry_rmedia"
    RECED_CHKBTN_SET        = "reced_cb_iisinset"
    RECED_ENTRY_SETORDER    = "reced_entry_isetorder"
    RECED_ENTRY_SETOF       = "reced_entry_isetof"
    RECED_ENTRY_COLLECTION  = "reced_lkentry_rcollection"
    RECED_ENTRY_ADDED       = "reced_dateentry_idateadded"
    RECED_ENTRY_RIPPED      = "reced_dateentry_idateripped"
    RECED_CHKBTN_SEGMENTED  = "reced_cb_iissegmented"
    RECED_CHKBTN_COMPILE    = "reced_cb_iiscompile"
    RECED_ENTRY_DBREF       = "reced_entry_rrecord"

    RECED_BTN_ARTIST        = "reced_btn_artist"
    RECED_BTN_PTIME         = "reced_btn_ptime"
    RECED_BTN_LABEL         = "reced_btn_label"
    RECED_BTN_GENRE         = "reced_btn_genre"
    RECED_BTN_MEDIUM        = "reced_btn_medium"
    RECED_BTN_COLLECTION    = "reced_btn_collection"

    RECED_BTN_OK            = "reced_btn_ok"
    RECED_BTN_CANCEL        = "reced_btn_cancel"


    #
    # Segment editor dialog
    #
    DLG_SEG_EDITOR      = "dlg_seg_editor"

    SEGED_ENTRY_ARTIST  = "seged_lkentry_rartist"
    SEGED_ENTRY_TITLE   = "seged_entry_stitle"
    SEGED_ENTRY_ORDER   = "seged_entry_iorder"
    SEGED_ENTRY_PTIME   = "seged_timeentry_iplaytime"
    SEGED_ENTRY_DBREF   = "seged_entry_rsegment"
    SEGED_ENTRY_RECREF  = "seged_entry_rrecord"

    SEGED_BTN_ARTIST    = "seged_btn_artist"
    SEGED_BTN_PTIME     = "seged_btn_ptime"

    SEGED_BTN_OK        = "seged_btn_ok"
    SEGED_BTN_CANCEL    = "seged_btn_cancel"


    #
    # Track editor dialog
    #
    DLG_TRK_EDITOR          = "dlg_trk_editor"

    TRKED_ENTRY_ORDER       = "trked_entry_iorder"
    TRKED_ENTRY_TITLE       = "trked_entry_stitle"
    TRKED_ENTRY_PTIME       = "trked_timeentry_iplaytime"
    TRKED_ENTRY_SEGORDER    = "trked_entry_isegorder"
    TRKED_CMB_RATING        = "trked_cmb_irating"
    #TRKED_CMB_TAGS          = "trked_cmb_tags"
    TRKED_ENTRY_PLAYED      = "trked_entry_iplayed"
    TRKED_ENTRY_LASTPLAYED  = "trked_dateentry_ilastplayed"
    TRKED_ENTRY_PREFORDER   = "trked_entry_ipreforder"
    TRKED_ENTRY_RECREF      = "trked_entry_rrecord"
    TRKED_ENTRY_SEGREF      = "trked_entry_rsegment"
    TRKED_ENTRY_DBREF       = "trked_entry_rtrack"
    TRKED_TV_TAGS           = "trked_tv_itags"

    TRKED_BTN_OK            = "trked_btn_ok"
    TRKED_BTN_CANCEL        = "trked_btn_cancel"

	#
	# Date selector
	#

	DLG_DATE_SELECTOR	= "dlg_date_selector"
	DATED_CALENDAR		= "dated_calendar"
	DATED_BTN_OK		= "dated_btn_ok"


    #
    # Filter window
    #

    FILTER_WINDOW       = "filter_window"

#     FLT_CB_PCOUNT       = "flt_cb_pcount"
#     FLT_CB_RATING       = "flt_cb_rating"
#     FLT_CB_PLAYTIME     = "flt_cb_playtime"
#     FLT_CB_PLAYDATES    = "flt_cb_playdates"
#     FLT_CB_TAGS         = "flt_cb_tags"
#     FLT_CB_GENRES       = "flt_cb_genres"
#     FLT_CB_ORIGINS      = "flt_cb_origins"
#     FLT_CB_MEDIAS       = "flt_cb_medias"

    FLT_EXP_PCOUNT       = "flt_exp_pcount"
    FLT_EXP_RATING       = "flt_exp_rating"
    FLT_EXP_PLAYTIME     = "flt_exp_playtime"
    FLT_EXP_PLAYDATES    = "flt_exp_playdates"
    FLT_EXP_TAGS         = "flt_exp_tags"
    FLT_EXP_GENRES       = "flt_exp_genres"
    FLT_EXP_ORIGINS      = "flt_exp_origins"
    FLT_EXP_MEDIAS       = "flt_exp_medias"

    FTV_TAGS            = "ftv_tags"
    FTV_GENRES          = "ftv_genres"
    FTV_ORIGINS         = "ftv_origins"
    FTV_MEDIAS          = "ftv_medias"
    
    FLT_CB_MATCHALL     = "flt_cb_matchall"
    FLT_CMB_MINRATING   = "flt_cmb_minrating"
    FLT_CMB_MAXRATING   = "flt_cmb_maxrating"
    FLT_BTN_FROMDATE    = "flt_btn_fromdate"
    FLT_BTN_TODATE      = "flt_btn_todate"
    FLT_ENTRY_FROMDATE  = "flt_entry_fromdate"
    FLT_ENTRY_TODATE    = "flt_entry_todate"
    FLT_BTN_APPLY       = "flt_btn_apply"
    FLT_BTN_CLEAR       = "flt_btn_clear"
#     FLT_BTN_SELALL      = "flt_btn_selall"
#     FLT_BTN_DESELALL    = "flt_btn_deselall"
    FLT_SPIN_MINP       = "flt_spin_minp"
    FLT_SPIN_MAXP       = "flt_spin_maxp"

    FLT_SPIN_MINPTIMEM  = "flt_spin_minptimem"
    FLT_SPIN_MINPTIMES  = "flt_spin_minptimes"
    FLT_SPIN_MAXPTIMEM  = "flt_spin_maxptimem"
    FLT_SPIN_MAXPTIMES  = "flt_spin_maxptimes"

    FLT_SPIN_PLENTRIES    = "flt_spin_plentries"
    FLT_SPIN_PCWEIGHT     = "flt_spin_pcweight"
    FLT_SPIN_RATINGWEIGHT = "flt_spin_ratingweight"
    FLT_CMB_SELECTBY      = "flt_cmb_selectby"
    FLT_BTN_PLGEN         = "flt_btn_plgen"

    #
    # Disabled controls when not in admin mode.
    #
    ADMIN_CTRLS = [ART_POPUP_ADD, ART_POPUP_DEL,
                   REC_POPUP_ADD, REC_POPUP_DEL, REC_POPUP_SEGADD,
                   # REC_POPUP_CPTITLE, REC_POPUP_TAGDIR, REC_POPUP_SEGORDER,
                   REC_POPUP_CPTITLE, REC_POPUP_SEGORDER,
                   # TRK_POPUP_ADD, TRK_POPUP_DEL, TRK_POPUP_TAGFILE,
                   TRK_POPUP_ADD, TRK_POPUP_DEL,
                   TRK_POPUP_SEGASS, TRK_POPUP_DELFROMFS, TRK_POPUP_UPDPTIME,
                   # REC_BTN_LABEL,
                   # SEG_BTN_ARTIST,
                   MM_FILE_CHECKCD, MM_FILE_IMPORTSQL, MM_FILE_IMPORTAUDIO,
                   MM_TOOLS_TAG_GENRE]
                   #MW_TOOLBAR] a revoir...


    #
    # Ratings and tags appear in popup menus
    #
    RATINGS = ["Non qualifié", "A chier", "Bouseux", "Limite", "Décent", "Cool", "Top fuel", "Transcendant", "Sublimissime"]
    TAGS = ["Girly", "Live", "Fun", "Calmos", "Fiesta", "Destroy!", "Satanique", "Instrumental", "Banned"]

    TAGS_GIRLY        = 1
    TAGS_LIVE         = 2
    TAGS_FUN          = 4
    TAGS_CALMOS       = 8
    TAGS_FIESTA       = 16
    TAGS_DESTROY      = 32
    TAGS_SATANIQUE    = 64
    TAGS_INSTRUMENTAL = 128
    TAGS_BANNED       = 256
end
