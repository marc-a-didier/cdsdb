
TaskData = Struct.new(:user_ref, :emitter, :file_info)

class TasksWindow < TopWindow

#     STATUS = ["Waiting", "Downloading...", "Done", "Uploading...", "Running...", "Cancelled"]
    STATUS = { :waiting => "Waiting", :downloading => "Downloading...", :done => "Done",
               :uploading => "Uploading...", :running => "Running...", :cancelled => "Cancelled" }

#     STAT_WAITING    = 0
#     STAT_DOWNLOAD   = 1
#     STAT_DONE       = 2
#     STAT_UPLOAD     = 3
#     STAT_RUN        = 4
#     STAT_CANCELLED  = 5

#     OP_AUDIO_DL = 0
#     OP_FILE_DL  = 1
#     OP_UPLOAD   = 2
#     OP_PROGRESS = 3

    TASKS = [:audio_download => "Audio download", :file_download => "File download",
             :upload => "Upload", :database => "Database operation"]

    COL_TASK     = 0
    COL_TITLE    = 1
    COL_PROGRESS = 2
    COL_STATUS   = 3
    COL_REF      = 4
#     COL_CLASS    = 5
#     COL_FILEINFO = 6


    def initialize(mc)
        super(mc, UIConsts::TASKS_WINDOW)

        @tv = @mc.glade[UIConsts::TASKS_TV]

        progress_renderer = Gtk::CellRendererProgress.new
        progress_renderer.sensitive = false
        progress_column = Gtk::TreeViewColumn.new("Progress", progress_renderer)
        progress_column.min_width = 150
        progress_column.set_cell_data_func(progress_renderer) { |column, cell, model, iter|
            if iter[COL_TASK] == :progress
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

        task_renderer = Gtk::CellRendererText.new
        task_column = Gtk::TreeViewColumn.new("Task", task_renderer)
        task_column.set_cell_data_func(task_renderer) { |col, renderer, model, iter| renderer.text = TASKS[iter[COL_TASK]] }

        status_renderer = Gtk::CellRendererText.new
        status_column = Gtk::TreeViewColumn.new("Status", status_renderer)
        status_column.set_cell_data_func(status_renderer) { |col, renderer, model, iter| renderer.text = STATUS[iter[COL_STATUS]] }

#         @tv.append_column(Gtk::TreeViewColumn.new("Task", Gtk::CellRendererText.new, :text => "")) #COL_OP))
        @tv.append_column(task_column)
        @tv.append_column(Gtk::TreeViewColumn.new("File", Gtk::CellRendererText.new, :text => COL_TITLE))
        @tv.append_column(progress_column)
#         @tv.append_column(Gtk::TreeViewColumn.new("Status", Gtk::CellRendererText.new, :text => "")) #COL_STATUS))
        @tv.append_column(status_column)

        @tv.model = Gtk::ListStore.new(String, String, Integer, String, Class) #, Class, String)

        @tv.signal_connect(:button_press_event) { |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
                @mc.glade[UIConsts::TASKS_POPUP_MENU].popup(nil, nil, event.button, event.time)
            end
        }

        @mc.glade[UIConsts::TKPM_CLOSE].signal_connect(:activate) { @mc.glade[UIConsts::MM_WIN_TASKS].signal_emit(:activate) }
        @mc.glade[UIConsts::TKPM_CLEAR].signal_connect(:activate) {
            @check_suspended = true
            index = 0
            while iter = @tv.model.get_iter(index.to_s)
                if iter[COL_STATUS] == :done || iter[COL_STATUS] == :cancelled
                    @tv.model.remove(iter)
                else
                    index += 1
                end
            end
            @tv.columns_autosize
            @check_suspended = false
        }
        # TODO: check if there is at least one download in progress before setting the flag
        @mc.glade[UIConsts::TKPM_CANCEL].signal_connect(:activate) { @cancel_flag = true }

        @chk_thread = nil
        @cancel_flag = false
        @check_suspended = false

        check_config
    end

    def check_waiting_tasks
        return if @check_suspended

        @tv.model.each { |model, path, iter|
            #next if iter[COL_OP] > OP_FILE_DL
            break if iter.nil? || iter[COL_STATUS] == :downloading
#             operation = OPERATIONS.index(iter[COL_TASK])
#             if operation <= OP_FILE_DL && iter[COL_STATUS] == STATUS[:waiting]
            if (iter[COL_TASK] == :file_download || iter[COL_TASK] == :audio_download) && iter[COL_STATUS] == :waiting
                @tv.set_cursor(iter.path, nil, false)
                iter[COL_STATUS] = :downloading
                if operation == :file_download
                    MusicClient.new.get_file(iter[COL_REF].file_info, self, iter)
                else
                    MusicClient.new.get_audio_file(self, iter, iter[COL_REF].user_ref.track.rtrack)
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

    def track_in_download?(dblink)
        @tv.model.each { |model, path, iter|
            return true if iter[COL_REF].user_ref.kind_of?(AudioLink) &&
                           iter[COL_REF].user_ref.track.rtrack == dblink.track.rtrack &&
                           (iter[COL_STATUS] == :waiting || iter[COL_STATUS] == :downloading)
        }
        return false
    end

    def new_task(type, emitter, title, user_ref, file_info)
        iter = @tv.model.append
        iter[COL_TASK]     = type #OPERATIONS[type]
        iter[COL_TITLE]    = title
        iter[COL_PROGRESS] = 0
        iter[COL_STATUS]   = :waiting
        iter[COL_REF]      = TaskData.new(user_ref, emitter, file_info)
#         iter[COL_REF]      = user_ref
#         iter[COL_CLASS]    = emitter
#         iter[COL_FILEINFO] = file_info
        return iter
    end

    def new_track_download(emitter, uilink)
        new_task(:audio_download, emitter, uilink.track.stitle, uilink, "")
    end

    def new_file_download(emitter, file_info, user_ref)
        new_task(:file_download, emitter, Utils::get_file_name(file_info), user_ref, file_info)
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size.to_f*100.0/tot_size.to_f).to_i
        return @cancel_flag ? Cfg::STAT_CANCELLED : Cfg::STAT_CONTINUE
    end

    def end_file_op(iter, file_name, status)
        if status == Cfg::STAT_CANCELLED && @cancel_flag
            @check_suspended = true
            @tv.model.each { |model, path, iter|
                if iter[COL_STATUS] == :downloading || iter[COL_STATUS] == :waiting
                    iter[COL_STATUS] = :cancelled
                end
            }
            @check_suspended = false
            @cancel_flag = false
        else
            iter[COL_PROGRESS] = 100
            iter[COL_STATUS]   = :done
            iter[COL_REF].user_ref.set_audio_file(file_name) if iter[COL_REF].user_ref.kind_of?(AudioLink)
            iter[COL_REF].emitter.dwl_file_name_notification(iter[COL_REF].user_ref, file_name) if iter[COL_REF].emitter
#             iter[COL_CLASS].dwl_file_name_notification(iter[COL_REF], file_name) if iter[COL_CLASS]
        end
    end

    def new_upload(title)
        iter = new_task(:upload, nil, title, 0, "Upload")
        iter[COL_STATUS] = :upload
        return iter
    end

    def new_progress(title)
        return new_task(:progress, nil, title, 0, "Statistics")
    end

    def update_progress(iter)
        iter[COL_PROGRESS] += 1
        Gtk.main_iteration while Gtk.events_pending?
    end

    def end_progress(iter)
        iter[COL_PROGRESS] = -1
        iter[COL_STATUS]   = :done
        Gtk.main_iteration while Gtk.events_pending?
    end
end
