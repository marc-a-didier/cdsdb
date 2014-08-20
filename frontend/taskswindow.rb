
TaskData = Struct.new(:user_ref, :emitter, :file_info)

class TasksWindow < TopWindow

    STATUS = ["Waiting", "Downloading...", "Done", "Uploading...", "Running...", "Cancelled"]

    STAT_WAITING    = 0
    STAT_DOWNLOAD   = 1
    STAT_DONE       = 2
    STAT_UPLOAD     = 3
    STAT_RUN        = 4
    STAT_CANCELLED  = 5

    TASK_AUDIO_DL = 0
    TASK_FILE_DL  = 1
    TASK_UPLOAD   = 2
    TASK_PROGRESS = 3

    TASKS = ["Audio download", "File download", "Upload", "Database operation"]

    COL_TASK     = 0
    COL_TITLE    = 1
    COL_PROGRESS = 2
    COL_STATUS   = 3
    COL_REF      = 4


    def initialize(mc)
        super(mc, UIConsts::TASKS_WINDOW)

        @tv = @mc.glade[UIConsts::TASKS_TV]

        progress_renderer = Gtk::CellRendererProgress.new
        progress_renderer.sensitive = false
        progress_column = Gtk::TreeViewColumn.new("Progress", progress_renderer)
        progress_column.min_width = 150
        progress_column.set_cell_data_func(progress_renderer) { |column, cell, model, iter|
            if iter[COL_TASK] == TASK_PROGRESS
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

        @tv.append_column(task_column)
        @tv.append_column(Gtk::TreeViewColumn.new("File", Gtk::CellRendererText.new, :text => COL_TITLE))
        @tv.append_column(progress_column)
        @tv.append_column(status_column)

        @tv.model = Gtk::ListStore.new(Integer, String, Integer, Integer, Class)

        @tv.signal_connect(:button_press_event) { |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
                @mc.glade[UIConsts::TASKS_POPUP_MENU].popup(nil, nil, event.button, event.time)
            end
        }

        @mc.glade[UIConsts::TKPM_CLOSE].signal_connect(:activate) { @mc.glade[UIConsts::MM_WIN_TASKS].signal_emit(:activate) }
        @mc.glade[UIConsts::TKPM_CLEAR].signal_connect(:activate) {
            @mutex.synchronize {
                index = 0
                while iter = @tv.model.get_iter(index.to_s)
                    if iter[COL_STATUS] == STAT_DONE || iter[COL_STATUS] == STAT_CANCELLED
                        @tv.model.remove(iter)
                    else
                        index += 1
                    end
                end
                @tv.columns_autosize
            }
        }

        # Check if there is at least one download in progress before setting the cancel flag
        @mc.glade[UIConsts::TKPM_CANCEL].signal_connect(:activate) {
            @tv.model.each { |model, path, iter|
                @has_cancelled = true if in_downloads?(iter)
                break if @has_cancelled
            }
        }

        @chk_thread = nil
        @has_cancelled = false
        @mutex = Mutex.new

        check_config
    end

    def check_waiting_tasks
        @mutex.synchronize {
            @tv.model.each { |model, path, iter|
                break if iter.nil? || iter[COL_STATUS] == STAT_DOWNLOAD

                if (iter[COL_TASK] == TASK_FILE_DL || iter[COL_TASK] == TASK_AUDIO_DL) && iter[COL_STATUS] == STAT_WAITING
                    @tv.set_cursor(iter.path, nil, false)
                    iter[COL_STATUS] = STAT_DOWNLOAD
                    if iter[COL_TASK] == TASK_FILE_DL
                        MusicClient.new.get_file(iter[COL_REF].file_info, self, iter)
                    else
                        MusicClient.new.get_audio_file(self, iter, iter[COL_REF].user_ref.track.rtrack)
                    end
                end
            }
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
            DBCACHE.set_audio_status_from_to(AudioLink::ON_SERVER, AudioLink::NOT_FOUND)
            @chk_thread.exit
            @chk_thread = nil
            @mc.glade[UIConsts::MAIN_WINDOW].title = "CDsDB -- [Local mode]"
TRACE.debug("task thread stopped".brown)
        end
    end

    def in_downloads?(iter)
        return iter[COL_STATUS] == STAT_WAITING || iter[COL_STATUS] == STAT_DOWNLOAD
    end

    def track_in_download?(dblink)
        @tv.model.each { |model, path, iter|
            return true if iter[COL_REF].user_ref.kind_of?(AudioLink) &&
                           iter[COL_REF].user_ref.track.rtrack == dblink.track.rtrack &&
                           in_downloads?(iter)
        }
        return false
    end

    def new_task(task, emitter, title, user_ref, file_info)
        iter = @tv.model.append
        iter[COL_TASK]     = task
        iter[COL_TITLE]    = title
        iter[COL_PROGRESS] = 0
        iter[COL_STATUS]   = STAT_WAITING
        iter[COL_REF]      = TaskData.new(user_ref, emitter, file_info)
        return iter
    end

    def new_track_download(emitter, uilink)
        new_task(TASK_AUDIO_DL, emitter, uilink.track.stitle, uilink, "")
    end

    def new_file_download(emitter, file_info, user_ref)
        new_task(TASK_FILE_DL, emitter, Utils::get_file_name(file_info), user_ref, file_info)
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size.to_f*100.0/tot_size.to_f).to_i
        return @has_cancelled ? Cfg::STAT_CANCELLED : Cfg::STAT_CONTINUE
    end

    def end_file_op(iter, file_name, status)
        if status == Cfg::STAT_CANCELLED && @has_cancelled
            @mutex.synchronize {
                @tv.model.each { |model, path, iter| iter[COL_STATUS] = STAT_CANCELLED if in_downloads?(iter) }
            }
            @has_cancelled = false
        else
            iter[COL_PROGRESS] = 100
            iter[COL_STATUS]   = STAT_DONE
            iter[COL_REF].user_ref.set_audio_file(file_name) if iter[COL_REF].user_ref.kind_of?(AudioLink)
            iter[COL_REF].emitter.dwl_file_name_notification(iter[COL_REF].user_ref, file_name) if iter[COL_REF].emitter
        end
    end

    def new_upload(title)
        iter = new_task(TASK_UPLOAD, nil, title, 0, "Upload")
        iter[COL_STATUS] = TASK_UPLOAD
        return iter
    end

    def new_progress(title)
        return new_task(TASK_PROGRESS, nil, title, 0, "Statistics")
    end

    def update_progress(iter)
        iter[COL_PROGRESS] += 1
        Gtk.main_iteration while Gtk.events_pending?
    end

    def end_progress(iter)
        iter[COL_PROGRESS] = -1
        iter[COL_STATUS]   = STAT_DONE
        Gtk.main_iteration while Gtk.events_pending?
    end
end
