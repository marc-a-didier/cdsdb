
class TasksWindow < TopWindow

    STATUS = ["Waiting", "Downloading...", "Done", "Uploading...", "Running...", "Cancelled"]

    STAT_WAITING    = 0
    STAT_DOWNLOAD   = 1
    STAT_DONE       = 2
    STAT_UPLOAD     = 3
    STAT_RUN        = 4
    STAT_CANCELLED  = 5

    COL_TASK_TYPE = 0
    COL_TITLE     = 1
    COL_PROGRESS  = 2
    COL_STATUS    = 3
    COL_TASK      = 4


    def initialize(mc)
        super(mc, GtkIDs::TASKS_WINDOW)

        @tv = GtkUI[GtkIDs::TASKS_TV]

        progress_renderer = Gtk::CellRendererProgress.new
        progress_renderer.sensitive = false
        progress_column = Gtk::TreeViewColumn.new("Progress", progress_renderer)
        progress_column.min_width = 150
        progress_column.set_cell_data_func(progress_renderer) do |column, cell, model, iter|
            cell.value = iter[COL_PROGRESS]
            cell.text  = iter[COL_PROGRESS].to_s+"%"
        end

        task_renderer = Gtk::CellRendererText.new
        task_column = Gtk::TreeViewColumn.new("Task", task_renderer)
        task_column.set_cell_data_func(task_renderer) { |col, renderer, model, iter| renderer.text = task_type(iter[COL_TASK]) }

        status_renderer = Gtk::CellRendererText.new
        status_column = Gtk::TreeViewColumn.new("Status", status_renderer)
        status_column.set_cell_data_func(status_renderer) { |col, renderer, model, iter| renderer.text = STATUS[iter[COL_STATUS]] }

        @tv.append_column(task_column)
        @tv.append_column(Gtk::TreeViewColumn.new("File", Gtk::CellRendererText.new, :text => COL_TITLE))
        @tv.append_column(progress_column)
        @tv.append_column(status_column)

        @tv.model = Gtk::ListStore.new(Symbol, String, Integer, Integer, Class)

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

                if iter[COL_STATUS] == STAT_WAITING
                    @tv.set_cursor(iter.path, nil, false)
                    iter[COL_STATUS] = iter[COL_TASK_TYPE].to_sym == :upload ? STAT_UPLOAD : STAT_DOWNLOAD

                    EpsdfClient.send(iter[COL_TASK_TYPE].to_sym == :upload ? :upload_resource : :download_resource, iter[COL_TASK])
                end
            end
        end
    end

    def check_config
        if Cfg.remote?
            if @chk_thread.nil?
                Trace.debug("Task thread started...".green) if Cfg.trace_network
                DBCache::Cache.set_audio_status_from_to(Audio::Status::NOT_FOUND, Audio::Status::UNKNOWN)
                @chk_thread = Thread.new do
                    loop do
                        check_waiting_tasks
                        sleep(1.0)
                    end
                end
            end
        elsif @chk_thread
            DBCache::Cache.set_audio_status_from_to(Audio::Status::ON_SERVER, Audio::Status::NOT_FOUND)
            @chk_thread.exit
            @chk_thread = nil
            Trace.debug("Task thread stopped".brown) if Cfg.trace_network
        end
    end

    def in_downloads?(iter)
        return iter[COL_STATUS] == STAT_WAITING || iter[COL_STATUS] == STAT_DOWNLOAD
    end

    def track_in_download?(dblink)
        @tv.model.each do |model, path, iter|
            return true if iter[COL_TASK].resource_type == :track &&
                           iter[COL_TASK].resource_data.track.rtrack == dblink.track.rtrack &&
                           in_downloads?(iter)
        end
        return false
    end

    def task_type(network_task)
        type = network_task.resource_type == :track ? 'Audio ' : 'File '
        return type+network_task.action.to_s
    end

    def task_title(network_task)
        if network_task.resource_type == :track && network_task.action == :download
            return network_task.resource_data.track.stitle
        else
            return File.basename(network_task.resource_data)
        end
    end

    def new_task(network_task)
        iter = @tv.model.append
        iter[COL_TASK_TYPE] = network_task.action
        iter[COL_TITLE]     = task_title(network_task)
        iter[COL_PROGRESS]  = 0
        iter[COL_STATUS]    = STAT_WAITING
        iter[COL_TASK]      = network_task

        network_task.task_owner = self
        network_task.task_ref   = iter

        return iter
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size*100.0/tot_size).to_i
        return @has_cancelled ? Epsdf::Protocol::STAT_ABRT : Epsdf::Protocol::STAT_CONT #Cfg::STAT_CANCELLED : Cfg::STAT_CONTINUE
    end

    def end_file_op(iter, status)
        if status == Cfg::STAT_CANCELLED && @has_cancelled
            @mutex.synchronize do
                @tv.model.each { |model, path, iter| iter[COL_STATUS] = STAT_CANCELLED if in_downloads?(iter) }
            end
            @has_cancelled = false
        else
            iter[COL_PROGRESS] = 100
            iter[COL_STATUS]   = STAT_DONE
            iter[COL_TASK].resource_owner.task_completed(iter[COL_TASK]) if iter[COL_TASK].resource_owner
        end
    end
end
