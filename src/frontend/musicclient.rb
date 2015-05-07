
module MusicClient

    def self.get_connection
        begin
            socket = TCPSocket.new(Cfg.server, Cfg.port)
        rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => ex
            puts "Connection error (#{ex.class} : #{ex})."
            GtkUI[GtkIDs::MW_SERVER_ACTION].send(:activate)
            GtkUtils.show_message("Can't connect to server #{Cfg.server} on port #{Cfg.port}.\n
                                   Config reset to local browsing mode.", Gtk::MessageDialog::ERROR)
            return nil
        end
        return socket
    end

    def self.close_connection(socket)
        if Cfg.sync_comms
            status = socket.gets.chomp
            Trace.net("server transaction [#{status.green}]")
        end
        socket.close
    end

    def self.hand_shake(msg)
        socket = get_connection
        return nil unless socket

        # Server always first responds 'OK' if the method is supported
        socket.puts(msg+Cfg::SYNC_HDR+Cfg::SYNC_MODE[Cfg.sync_comms])
        response = socket.gets.chomp
        Trace.net("[#{msg.magenta}] <-> [#{response.green}]")

        return socket if response == Cfg::MSG_OK

        # If response is not OK, we're fucked... or it's a bad metod
        # If were here, the remote mode is active. Deactivate it if fucked...
        GtkUI[GtkIDs::MW_SERVER_ACTION].send(:activate) if response == Cfg::MSG_FUCKED

        socket.close
        return nil
    end

    def self.is_server_alive?
        return false unless socket = hand_shake("is alive")
        Trace.net("server alive request [#{socket.gets.chomp.green}]")
        close_connection(socket)
        return true
    end

    def self.get_server_db_version
        return "" unless socket = hand_shake("get db version")
        db_version = socket.gets.chomp
        close_connection(socket)
        return db_version
    end

    def self.check_multiple_audio(tracks)
        return [] unless socket = hand_shake("check multiple audio")
        socket.puts(tracks)
        rs = socket.gets.chomp.split(" ")
        close_connection(socket)
        return rs
    end

    def self.exec_sql(sql)
        return unless socket = hand_shake("exec sql")
        socket.puts(sql)
        close_connection(socket)
    end

    def self.exec_batch(sql)
        return unless socket = hand_shake("exec batch")
        socket.puts(sql.gsub(/\n/, '\n'))
        close_connection(socket)
    end

    def self.renumber_play_list(rplist)
        return unless socket = hand_shake("renumber play list")
        socket.puts(rplist.to_s)
        close_connection(socket)
    end

    def self.rename_audio(rtrack, new_title)
        return unless socket = hand_shake("rename audio")
        socket.puts(rtrack.to_s)
        socket.puts(new_title)
        close_connection(socket)
    end

    #
    # Get outdated resources for a resource type and
    # return them as an array of files
    #
    # OUT: resource type
    # IN : an array of arrays [ [file, modification time], ... ] in json format
    #
    def self.resources_to_update(resource_type)
        return [] unless socket = hand_shake("resources list")
        socket.puts(resource_type.to_s)
        updates = []
        JSON.parse(socket.gets.chomp).each do |file, mtime|
            updates << file if !File.exists?(Cfg.dir(resource_type)+file) || File.mtime(Cfg.dir(resource_type)+file).to_i < mtime
        end
        return updates
    end

    #
    # Download resource from server
    #
    # OUT: expected resource type
    # OUT: track PK is resource is a track, otherwise file name
    # OUT: transfer block size, negative if resource is track and want smallest file size
    # IN : resource size
    # repeated:
    #   IN : block data size
    #   IN : block data
    #   OUT: status (continue/cancel)
    #
    def self.download_resource(network_task)
        return false unless socket = hand_shake("download resource")

        # Send expected resource type
        socket.puts(network_task.resource_type.to_s)

        if network_task.resource_type == :track
            # In case of audio download, resource_data is expected to be an audio link
            # Send the track primary key for track and get back the file name on the server file system
            socket.puts(network_task.resource_data.track.rtrack)
            file = Cfg.music_dir+socket.gets.chomp
        else
            # In other cases sends the file name
            socket.puts(network_task.resource_data)

            # Special case when updating db: set local file name to a temporary
            # name while downloading. The new db will be setup at the end of the download
            # network_task.resource_data is changed so the caller knows under which name the file is saved
            network_task.resource_data += '.dwl' if network_task.resource_type == :db

            # Set local file path to the resource full path name
            file = Cfg.dir(network_task.resource_type)+network_task.resource_data
        end

        # Send the data blocks size expected by the client
        if network_task.resource_type == :track && Cfg.size_over_quality
            # If we prefer small size over quality, pass the block size as a negative number
            socket.puts((-Cfg.tx_block_size).to_s)
        else
            socket.puts(Cfg.tx_block_size)
        end

        status = Cfg::STAT_CONTINUE

        # Create destination path & file
        FileUtils.mkpath(File.dirname(file))
        File.open(file, 'w') do |f|

            # Get the total file size
            file_size = socket.gets.chomp.to_i
            if file_size > 0
                curr_size = 0

                # Get the current data block size and loop while not size > 0 and not interrupted
                while ((size = socket.gets.chomp.to_i) > 0) &&  status == Cfg::STAT_CONTINUE
                    curr_size += size
                    f.write(socket.read(size))
                    status = network_task.task_owner.update_file_op(network_task.task_ref, curr_size, file_size)
                    socket.puts(status == Cfg::STAT_CONTINUE ? Cfg::MSG_CONTINUE : Cfg::MSG_CANCELLED)
                end
            end
        end

        FileUtils.rm(file) if status == Cfg::MSG_CANCELLED
        close_connection(socket)
        network_task.task_owner.end_file_op(network_task.task_ref, status)
    end

    #
    # Check if a resource is available on the server
    #
    # OUT: resource type searched for
    # OUT: file name searched for
    # IN : '1' if resouce found, '0' otherwise
    #
    def self.has_resource(resource_type, file)
        return false unless socket = hand_shake("has resource")
        socket.puts(resource_type.to_s)
        socket.puts(Cfg.relative_path(resource_type, file))
        status = socket.gets.chomp
        close_connection(socket)
        Trace.net("checked resource '#{file.cyan}'")
        return status == '1'
    end

    #
    # Upload a resource to the server
    #
    # OUT: resource type
    # OUT: resource file name
    # OUT: resource file size
    # repeated:
    #   OUT: block data size
    #   OUT: block data
    #   OUT: status (continue/cancel)
    # OUT: '0' block size
    #
    def self.upload_resource(network_task)
        return false unless socket = hand_shake("upload resource")

        status = Cfg::STAT_CONTINUE

        file_size = File.size(network_task.resource_data)

        socket.puts(network_task.resource_type.to_s)
        socket.puts(Cfg.relative_path(network_task.resource_type, network_task.resource_data))
        if file_size > 0
            curr_size = 0
            socket.puts(file_size.to_s)
            File.open(network_task.resource_data, "r") do |f|
                while (data = f.read(Cfg.tx_block_size)) && status == Cfg::STAT_CONTINUE
                    curr_size += data.size
                    socket.puts(data.size.to_s)
                    socket.write(data)
                    status = network_task.task_owner.update_file_op(network_task.task_ref, curr_size, file_size)
                    socket.puts(status == Cfg::STAT_CONTINUE ? Cfg::MSG_CONTINUE : Cfg::MSG_CANCELLED)
                end
            end
        end
        socket.puts('0')
        close_connection(socket)
        network_task.task_owner.end_file_op(network_task.task_ref, status)
    end
end
