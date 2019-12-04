
class TasksWindow < TopWindow

    STATUS = ['Done', 'Cancelled', 'Waiting', 'Downloading...', 'Uploading...', 'Exporting...']


    STAT_DONE       = 0
    STAT_CANCELLED  = 1
    STAT_WAITING    = 2
    STAT_DOWNLOAD   = 3
    STAT_UPLOAD     = 4
    STAT_EXPORT     = 5

    COL_TASK_TYPE = 0
    COL_TITLE     = 1
    COL_PROGRESS  = 2
    COL_STATUS    = 3
    COL_TASK      = 4

    TASK_TO_STAT  = { :download => STAT_DOWNLOAD, :upload => STAT_UPLOAD, :export => STAT_EXPORT }


    Task = Struct.new(:action,         # action type (download/upload, export)
                      :resource_type,  # type of file to work with
                      :resource_data,  # may be a file name or a cache link
                      :resource_owner, # call resource_owner.task_completed at the end
                      :task_owner,
                      :task_ref,
                      :executed) do

        def network_task?
            return self.action != :export
        end
    end

    def initialize(mc)
        super(mc, GtkIDs::TASKS_WINDOW)

        @tv = GtkUI[GtkIDs::TASKS_TV]

        progress_renderer = Gtk::CellRendererProgress.new
        progress_renderer.sensitive = false
        progress_column = Gtk::TreeViewColumn.new('Progress', progress_renderer)
        progress_column.min_width = 150
        progress_column.set_cell_data_func(progress_renderer) do |column, cell, model, iter|
            cell.value = iter[COL_PROGRESS]
            cell.text  = iter[COL_PROGRESS].to_s+"%"
        end

        task_renderer = Gtk::CellRendererText.new
        task_column = Gtk::TreeViewColumn.new('Task', task_renderer)
        task_column.set_cell_data_func(task_renderer) { |col, renderer, model, iter| renderer.text = task_type(iter[COL_TASK]) }

        status_renderer = Gtk::CellRendererText.new
        status_column = Gtk::TreeViewColumn.new('Status', status_renderer)
        status_column.set_cell_data_func(status_renderer) { |col, renderer, model, iter| renderer.text = STATUS[iter[COL_STATUS]] }

        @tv.append_column(task_column)
        @tv.append_column(Gtk::TreeViewColumn.new('File', Gtk::CellRendererText.new, :text => COL_TITLE))
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
                    iter[COL_STATUS] < STAT_WAITING ? @tv.model.remove(iter) : index += 1
                end
                @tv.columns_autosize
            end
        end

        # Check if there is at least one download in progress before setting the cancel flag
        GtkUI[GtkIDs::TKPM_CANCEL].signal_connect(:activate) do
            @mutex.synchronize do
                @tv.model.each do |model, path, iter|
                    if iter[COL_STATUS] >= STAT_WAITING
                        iter[COL_STATUS] = STAT_CANCELLED
                        iter[COL_TASK].executed = Time.now.to_i
                    end
                end
            end
        end

        @mutex = Mutex.new

        Trace.debug('Task thread starting...'.green)
        Thread.new do
            Kernel.loop do
                @mutex.synchronize { check_tasks } unless @mutex.locked?
                sleep(1.0)
            end
        end
    end

    def check_tasks
        @tv.model.each do |model, path, iter|
            # Exit loop if a task is already processing
            break if iter[COL_STATUS] > STAT_WAITING

            if iter[COL_STATUS] == STAT_WAITING
                @tv.set_cursor(iter.path, nil, false)
                iter[COL_STATUS] = TASK_TO_STAT[iter[COL_TASK].action]
                iter[COL_STATUS] = iter[COL_TASK].network_task? ? (Epsdf::Client.new.process_task(iter[COL_TASK]) ? 0 : 1) :
                                                                  (FSExporter.process_task(iter[COL_TASK]) ? 0 : 1)
                iter[COL_TASK].executed = Time.now.to_i
                break # Process one task at a time
            end

            # Automatically remove executed tasks after a delay
            if iter[COL_TASK].executed && (Time.now.to_i-iter[COL_TASK].executed > 5*60)
                @tv.model.remove(iter)
                @tv.columns_autosize
                break # Must exit, the each loop is now broken since iter was removed
            end
        end
    end

    def remote_config_updated
        # Called when the server connection is switched.
        # If Cfg.remote? is true it was false before and inversely
        if Cfg.remote?
            DBCache::Cache.set_audio_status_from_to(Audio::Status::NOT_FOUND, Audio::Status::UNKNOWN)
        else
            DBCache::Cache.set_audio_status_from_to(Audio::Status::ON_SERVER, Audio::Status::NOT_FOUND)
        end
        Trace.debug('DB cache audio status reset'.red)
    end

    def track_in_download?(dblink)
        @tv.model.each do |model, path, iter|
            return true if iter[COL_TASK].resource_type == :track &&
                           iter[COL_TASK].resource_data.track.rtrack == dblink.track.rtrack &&
                           iter[COL_STATUS] >= STAT_WAITING
        end
        return false
    end

    def task_type(task)
        return (task.resource_type == :track ? 'Audio ' : 'File ')+task.action.to_s
    end

    def task_title(task)
        return task.resource_type == :track && task.action == :download ? task.resource_data.track.stitle :
                                                                          File.basename(task.resource_data)
    end

    def new_task(task)
        return nil if task.network_task? && !Cfg.remote

        iter = @tv.model.append
        iter[COL_TASK_TYPE] = task.action
        iter[COL_TITLE]     = task_title(task)
        iter[COL_PROGRESS]  = 0
        iter[COL_STATUS]    = STAT_WAITING
        iter[COL_TASK]      = task

        task.task_owner = self
        task.task_ref   = iter

        return iter
    end

    def update_file_op(iter, curr_size, tot_size)
        iter[COL_PROGRESS] = (curr_size*100.0/tot_size).to_i
        Gtk.main_iteration while Gtk.events_pending?
        # Don't think it makes any sense, the cancel jobs action must acquire the mutex and it can't
        # get it while the task is in progess...
        return iter[COL_STATUS] == STAT_CANCELLED ? Epsdf::Protocol::STAT_ABRT : Epsdf::Protocol::STAT_CONT
    end

    def end_file_op(iter, status)
        iter[COL_STATUS] = status ? STAT_DONE : STAT_CANCELLED
        iter[COL_TASK].resource_owner.task_completed(iter[COL_TASK]) if status && iter[COL_TASK].resource_owner
    end
end
