
module FSExporter

    def self.export_tracks_to_device(mc, tracks)
        # Remmove tracks without audio file and add tasks to the tasks window
        tracks.delete_if { |track_data| track_data.setup_audio_file.status != Audio::Status::OK }.
               each { |track_data| mc.tasks.new_task(TasksWindow::Task.new(:export, :track, track_data.audio_file, nil)) }
    end

    def self.process_task(task)
        dest_file = task.resource_data.sub(/^#{Cfg.music_dir}/, Cfg.device_dir)

        if File.exists?(dest_file)
            Trace.net("Export: file #{dest_file} already exists.")
            return false
        else
            Trace.net("Export: copying #{task.resource_data} to #{dest_file}")
            FileUtils.mkpath(File.dirname(dest_file))
            file_size = File.size(task.resource_data)
            curr_size = 0
            File.open(task.resource_data, 'rb') do |inf|
                File.open(dest_file, 'wb') do |outf|
                    while (data = inf.read(256*1024))
                        curr_size += data.size
                        task.task_owner.update_file_op(task.task_ref, curr_size, file_size)
                        outf.write(data)
                    end
                    task.task_owner.end_file_op(task.task_ref, true)
                end
            end
            return true
        end
    end
end
