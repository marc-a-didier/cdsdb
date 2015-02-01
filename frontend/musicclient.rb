# !/usr/bin/env ruby

require 'socket'

module MusicClient

    def self.get_connection
        begin
            socket = TCPSocket.new(Cfg.server, Cfg.port)
        rescue Errno::ECONNREFUSED => ex
            puts "Connection error (#{ex.class} : #{ex})."
            Cfg.remote = false
            GtkUtils.show_message("Can't connect to server #{Cfg.server} on port #{Cfg.port}.\n
                                   Config reset to local browsing mode.", Gtk::MessageDialog::ERROR)
            return nil
        end
        return socket
    end

    def self.close_connection(socket)
        status = socket.gets.chomp
        Trace.debug("<--> Server response is: #{status.green}") if Cfg.trace_network
        socket.close
    end

    def self.is_server_alive?
        return false unless socket = get_connection
        socket.puts("is alive")
        Trace.debug("<--> Server alive request: #{socket.gets.chomp.green}") if Cfg.trace_network
        close_connection(socket)
        return true
    end

    def self.get_server_db_version
        return "" unless socket = get_connection
        Trace.debug("get db version") if Cfg.trace_network
        db_version = ""
        socket.puts("get db version")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> DB version #{Cfg::MSG_OK.green}") if Cfg.trace_network
            db_version = socket.gets.chomp
        end
        close_connection(socket)
        return db_version
    end

    def self.check_multiple_audio(tracks)
        return [] unless socket = get_connection
        socket.puts("check multiple audio")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Check audio #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(tracks)
            rs = socket.gets.chomp.split(" ")
        end
        close_connection(socket)
        return rs
    end

    def self.update_stats(rtrack)
        return unless socket = get_connection
        socket.puts("update stats")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Update stats #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(rtrack.to_s)
        end
        close_connection(socket)
    end

    def self.exec_sql(sql)
        return unless socket = get_connection
        socket.puts("exec sql")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Exec SQL #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(sql)
        end
        close_connection(socket)
    end

    def self.exec_batch(sql)
        return unless socket = get_connection
        socket.puts("exec batch")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Exec batch #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(sql.gsub(/\n/, '\n'))
        end
        close_connection(socket)
    end

    def self.renumber_play_list(rplist)
        return unless socket = get_connection
        socket.puts("renumber play list")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Renumber play list #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(rplist.to_s)
        end
        close_connection(socket)
    end

    def self.synchronize_resources
        return unless socket = get_connection
        resources = []
        socket.puts("synchronize resources")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Sync resources #{Cfg::MSG_OK.green}") if Cfg.trace_network
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                resources << str unless Utils.has_matching_file?(str) #File.exists?(str)
                str = socket.gets.chomp
            end
        end
        close_connection(socket)
        Trace.debug("<--> Resources list received.".green) if Cfg.trace_network
        p resources
        return resources
    end

    def self.synchronize_sources
        return unless socket = get_connection
        files = []
        socket.puts("synchronize sources")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Sync sources #{Cfg::MSG_OK.green}") if Cfg.trace_network
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                files << str unless Utils.has_matching_file?(str)
                str = socket.gets.chomp
            end
        end
        close_connection(socket)
        Trace.debug("<--> Sources list received.".green) if Cfg.trace_network
        return files
    end

    def self.rename_audio(rtrack, new_title)
        return "" unless socket = get_connection
        Trace.debug("rename audio") if Cfg.trace_network
        socket.puts("rename audio")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Rename audio #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(rtrack.to_s)
            socket.puts(new_title)
        end
        close_connection(socket)
    end

    def self.get_audio_file(tasks, task_id, rtrack)
        return "" unless socket = get_connection
        Trace.debug("send audio") if Cfg.trace_network
        socket.puts("send audio")
        file = ""
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Send audio #{Cfg::MSG_OK.green}") if Cfg.trace_network
            Trace.debug("<--> Negociated block size is #{Cfg.tx_block_size.to_s} bytes".brown) if Cfg.trace_network
            socket.puts(Cfg.tx_block_size.to_s)
            if socket.gets.chomp.to_i == Cfg.tx_block_size
                socket.puts(rtrack.to_s)
                size = socket.gets.chomp.to_i
                unless size == 0
                    file = socket.gets.chomp
                    FileUtils.mkpath(Cfg.music_dir+File.dirname(file))
                    file = Cfg.music_dir+file
                    download_file(tasks, task_id, file, size, socket)
                end
            end
        end
        close_connection(socket)
        return file
    end

    def self.get_file(file_name, tasks, task_id)
        return false unless socket = get_connection
        size = 0
        Trace.debug("send file") if Cfg.trace_network
        socket.puts("send file")
        if socket.gets.chomp == Cfg::MSG_OK
            Trace.debug("<--> Send file #{Cfg::MSG_OK.green}") if Cfg.trace_network
            socket.puts(Cfg.tx_block_size.to_s)
            if socket.gets.chomp.to_i == Cfg.tx_block_size
                Trace.debug("<--> Negociated block size is #{Cfg.tx_block_size.to_s} bytes".brown) if Cfg.trace_network
                socket.puts(file_name)
                size = socket.gets.chomp.to_i
                download_file(tasks, task_id, Utils.replace_dir_name(file_name), size, socket) unless size == 0
            end
        end
        close_connection(socket)
        return size > 0
    end

    def self.download_file(tasks, task_id, file_name, file_size, socket)
        curr_size = 0
        status = Cfg::MSG_CONTINUE
        FileUtils.mkpath(File.dirname(file_name)) #unless File.directory?(File.dirname(file_name))
        f = File.new(file_name, "wb")
        while (data = socket.read(Cfg.tx_block_size))
            curr_size += data.size
            status = tasks.update_file_op(task_id, curr_size, file_size)
            socket.puts(status == Cfg::STAT_CONTINUE ? Cfg::MSG_CONTINUE : Cfg::MSG_CANCELLED) if curr_size < file_size
            break if status == Cfg::MSG_CANCELLED
            f.write(data)
        end
        tasks.end_file_op(task_id, file_name, status)
        f.close
        FileUtils.rm(file_name) if status == Cfg::MSG_CANCELLED
    end
end
