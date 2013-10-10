
class TasksWindow < TopWindow

    STATUS = ["Waiting", "Downloading...", "Done", "Uploading...", "Running..."]

    STAT_WAITING    = 0
    STAT_DOWNLOAD   = 1
    STAT_DONE       = 2
    STAT_UPLOAD     = 3
    STAT_RUN        = 4

    OP_AUDIO_DL = 0
    OP_FILE_DL  = 1
    OP_UPLOAD   = 2
    OP_PROGRESS = 3

    OPERATIONS = ["Audio download", "File download", "Upload", "Database operation"]

    COL_OP       = 0
    COL_TITLE    = 1
    COL_PROGRESS = 2
    COL_STATUS   = 3
    COL_REF      = 4
    COL_CLASS    = 5
    COL_FILEINFO = 6


    def initialize(mc)
        super(mc, UIConsts::TASKS_WINDOW)

        @tv = @mc.glade[UIConsts::TASKS_TV]

        prgs_renderer = Gtk::CellRendererProgress.new
        prgs_renderer.sensitive = false
        prgs_col = Gtk::TreeViewColumn.new("Progress", prgs_renderer)
        prgs_col.min_width = 150
        prgs_col.set_cell_data_func(prgs_renderer) { |column, cell, model, iter|
            if iter[COL_OP] == OPERATIONS[OP_PROGRESS]
                if iter[COL_PROGRESS] == -1
                    #cell.value = 1.0
                    #cell.text  = ""
                    #cell.pulse = 2**31-1
                    cell.pulse = -1 #GLib::MAXINT #1073741823 # 2147483647
                else
                    cell.pulse += 1
                end
            else
                cell.value = iter[COL_PROGRESS]
                cell.text  = iter[COL_PROGRESS].to_s+"%"
            end
        }

        @tv.append_column(Gtk::TreeViewColumn.new("Task", Gtk::CellRendererText.new, :text => COL_OP))
        @tv.append_column(Gtk::TreeViewColumn.new("File", Gtk::CellRendererText.new, :text => COL_TITLE))
        @tv.append_column(prgs_col)
        @tv.append_column(Gtk::TreeViewColumn.new("Status", Gtk::CellRendererText.new, :text => COL_STATUS))

        @tv.model = Gtk::ListStore.new(String, String, Integer, String, Class, Class, String)

        @tv.signal_connect(:button_press_event) { |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
                @mc.glade[UIConsts::TASKS_POPUP_MENU].popup(nil, nil, event.button, event.time)
            end
        }

        @mc.glade[UIConsts::TKPM_CLOSE].signal_connect(:activate) { @mc.glade[UIConsts::MM_WIN_TASKS].signal_emit(:activate) }
        @mc.glade[UIConsts::TKPM_CLEAR].signal_connect(:activate) {
            while @tv.model.get_iter("0") && @tv.model.get_iter("0")[COL_STATUS] == STATUS[STAT_DONE]
                @tv.model.remove(@tv.model.get_iter("0"))
            end
            @tv.columns_autosize
        }

        @chk_thread = nil
        check_config
    end

    def check_waiting_tasks
        @tv.model.each { |model, path, iter|
            #next if iter[COL_OP] > OP_FILE_DL
            break if iter.nil? || iter[COL_STATUS] == STATUS[STAT_DOWNLOAD]
            operation = OPERATIONS.index(iter[COL_OP])
            if operation <= OP_FILE_DL && iter[COL_STATUS] == STATUS[STAT_WAITING]
                @tv.set_cursor(iter.path, nil, false)
                iter[COL_STATUS] = STATUS[STAT_DOWNLOAD]
                if operation == OP_FILE_DL
                    MusicClient.new.get_file(iter[COL_FILEINFO], self, iter)
                else
                    MusicClient.new.get_audio_file(self, iter, iter[COL_REF].track.rtrack)
                end

                #break
            end
        }
    end

    def check_config
        if CFG.remote?
            if @chk_thread.nil?
TRACE.debug("task thread started...".green)
                DBCACHE.set_audio_status_from_to(AudioLink::NOT_FOUND, AudioLink::UNKNOWN)
                @mc.glade[UIConsts::MAIN_WINDOW].title = "CDsDB -- [Connected mode]"
                @chk_thread = Thread.new {
                    loop do
                        check_waiting_tasks
                        sleep(1.0)
                    end
                }
            end
        elsif !@chk_thread.nil?
            @chk_thread.exit
            @chk_thread = nil
            DBCACHE.set_audio_status_from_to(AudioLink::ON_SERVER, AudioLink::NOT_FOUND)
            @mc.glade[UIConsts::MAIN_WINDOW].title = "CDsDB -- [Local mode]"
TRACE.debug("task thread stopped".brown)
        end
    end

    def new_task(type, emitter, title, user_ref, file_info)
        iter = @tv.model.append
        iter[COL_OP]       = OPERATIONS[type]
        iter[COL_TITLE]    = title
        iter[COL_PROGRESS] = 0
        iter[COL_STATUS]   = STATUS[STAT_WAITING]
        iter[COL_REF]      = user_ref
        iter[COL_CLASS]    = emitter
        iter[COL_FILEINFO] = file_info
        return iter
    end

    def new_track_download(emitter, uilink)
        new_task(OP_AUDIO_DL, emitter, uilink.track.stitle, uilink, "")
    end

    def new_file_download(emitter, file_info, user_ref)
        new_task(OP_FILE_DL, emitter, Utils::get_file_name(file_info), user_ref, file_info)
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size.to_f*100.0/tot_size.to_f).to_i
    end

    def end_file_op(iter, file_name)
        iter[COL_PROGRESS] = 100
        iter[COL_STATUS]   = STATUS[STAT_DONE]
        iter[COL_REF].set_audio_file(file_name) if iter[COL_REF].kind_of?(AudioLink)
        iter[COL_CLASS].dwl_file_name_notification(iter[COL_REF], file_name) if iter[COL_CLASS]
    end

    def new_upload(title)
        iter = new_task(OP_UPLOAD, nil, title, 0, "Upload")
        iter[COL_STATUS] = STATUS[STAT_UPLOAD]
        return iter
    end

    def new_progress(title)
        return new_task(OP_PROGRESS, nil, title, 0, "Statistics")
    end

    def update_progress(iter)
        iter[COL_PROGRESS] += 1
        Gtk.main_iteration while Gtk.events_pending?
    end

    def end_progress(iter)
        iter[COL_PROGRESS] = -1
        iter[COL_STATUS]   = STATUS[STAT_DONE]
        Gtk.main_iteration while Gtk.events_pending?
    end
end
