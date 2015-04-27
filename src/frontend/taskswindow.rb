
class TasksWindow < TopWindow

    TaskData = Struct.new(:user_ref, :emitter, :file_info)

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
        super(mc, GtkIDs::TASKS_WINDOW)

        @tv = GtkUI[GtkIDs::TASKS_TV]

        progress_renderer = Gtk::CellRendererProgress.new
        progress_renderer.sensitive = false
        progress_column = Gtk::TreeViewColumn.new("Progress", progress_renderer)
        progress_column.min_width = 150
        progress_column.set_cell_data_func(progress_renderer) do |column, cell, model, iter|
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
        end

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

        @tv.signal_connect(:button_press_event) do |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
                GtkUI[GtkIDs::TASKS_POPUP_MENU].popup(nil, nil, event.button, event.time)
            end
        end

        GtkUI[GtkIDs::TKPM_CLOSE].signal_connect(:activate) { GtkUI[GtkIDs::MM_WIN_TASKS].signal_emit(:activate) }
        GtkUI[GtkIDs::TKPM_CLEAR].signal_connect(:activate) do
            @mutex.synchronize do
                index = 0
                while iter = @tv.model.get_iter(index.to_s)
                    if iter[COL_STATUS] == STAT_DONE || iter[COL_STATUS] == STAT_CANCELLED
                        @tv.model.remove(iter)
                    else
                        index += 1
                    end
                end
                @tv.columns_autosize
            end
        end

        # Check if there is at least one download in progress before setting the cancel flag
        GtkUI[GtkIDs::TKPM_CANCEL].signal_connect(:activate) do
            @tv.model.each do |model, path, iter|
                @has_cancelled = true if in_downloads?(iter)
                break if @has_cancelled
            end
        end

        @chk_thread = nil
        @has_cancelled = false
        @mutex = Mutex.new

        check_config
    end

    def check_waiting_tasks
        @mutex.synchronize do
            @tv.model.each do |model, path, iter|
                break if iter.nil? || iter[COL_STATUS] == STAT_DOWNLOAD || iter[COL_STATUS] == STAT_UPLOAD

                if (iter[COL_TASK] == TASK_FILE_DL || iter[COL_TASK] == TASK_AUDIO_DL ||
                    iter[COL_TASK] == TASK_UPLOAD) && iter[COL_STATUS] == STAT_WAITING
                    @tv.set_cursor(iter.path, nil, false)
                    iter[COL_STATUS] = STAT_DOWNLOAD
                    case iter[COL_TASK]
                        when TASK_FILE_DL then  MusicClient.get_file(iter[COL_REF].file_info, self, iter)
                        when TASK_AUDIO_DL then MusicClient.get_audio_file(self, iter, iter[COL_REF].user_ref.track.rtrack)
                        when TASK_UPLOAD then   MusicClient.upload_file(self, iter, iter[COL_REF].user_ref.track.rtrack)
                    end
                end
            end
        end
    end

    def check_config
        if Cfg.remote?
            if @chk_thread.nil?
                Trace.debug("Task thread started...".green) if Cfg.trace_network
#                 MusicClient.is_server_alive?
                DBCache::Cache.set_audio_status_from_to(Audio::Status::NOT_FOUND, Audio::Status::UNKNOWN)
#                 GtkUI[GtkIDs::MAIN_WINDOW].title = "CDsDB -- [Connected mode]"
                @chk_thread = Thread.new do
                    loop do
                        check_waiting_tasks
                        sleep(1.0)
                    end
                end
            end
        elsif !@chk_thread.nil?
            DBCache::Cache.set_audio_status_from_to(Audio::Status::ON_SERVER, Audio::Status::NOT_FOUND)
            @chk_thread.exit
            @chk_thread = nil
#             GtkUI[GtkIDs::MAIN_WINDOW].title = "CDsDB -- [Local mode]"
            Trace.debug("Task thread stopped".brown) if Cfg.trace_network
        end
    end

    def in_downloads?(iter)
        return iter[COL_STATUS] == STAT_WAITING || iter[COL_STATUS] == STAT_DOWNLOAD
    end

    def track_in_download?(dblink)
        @tv.model.each do |model, path, iter|
            return true if iter[COL_REF].user_ref.kind_of?(Audio::Link) &&
                           iter[COL_REF].user_ref.track.rtrack == dblink.track.rtrack &&
                           in_downloads?(iter)
        end
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

    def new_track_download(emitter, xlink)
        new_task(TASK_AUDIO_DL, emitter, xlink.track.stitle, xlink, "")
    end

    def new_file_download(emitter, file_info, user_ref)
        new_task(TASK_FILE_DL, emitter, Utils.get_file_name(file_info), user_ref, file_info)
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size*100.0/tot_size).to_i
        return @has_cancelled ? Cfg::STAT_CANCELLED : Cfg::STAT_CONTINUE
    end

    def end_file_op(iter, file_name, status)
        if status == Cfg::STAT_CANCELLED && @has_cancelled
            @mutex.synchronize do
                @tv.model.each { |model, path, iter| iter[COL_STATUS] = STAT_CANCELLED if in_downloads?(iter) }
            end
            @has_cancelled = false
        else
            iter[COL_PROGRESS] = 100
            iter[COL_STATUS]   = STAT_DONE
            iter[COL_REF].user_ref.set_audio_state(Audio::Status::OK, file_name) if iter[COL_TASK] == TASK_AUDIO_DL #&& iter[COL_REF].user_ref.kind_of?(Audio::Link)
            iter[COL_REF].emitter.dwl_file_name_notification(iter[COL_REF].user_ref, file_name) if iter[COL_REF].emitter
        end
    end

    def new_upload(user_ref)
        iter = new_task(TASK_UPLOAD, nil, user_ref.track.stitle, user_ref, "Upload")
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
