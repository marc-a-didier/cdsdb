# !/usr/bin/env ruby

require 'socket'

class MusicClient

    def get_connection
        begin
            socket = TCPSocket.new(CFG.server, CFG.port)
        rescue Errno::ECONNREFUSED => ex
            puts "Connection error (#{ex.class} : #{ex})."
            CFG.set_local_mode
            GtkUtils.show_message("Can't connect to server #{CFG.server} on port #{CFG.port}.\n
                                   Config reset to local browsing mode.", Gtk::MessageDialog::ERROR)
            return nil
        end
        return socket
    end


    def get_server_db_version
        return "" unless socket = get_connection
        TRACE.debug("get db version")
        db_version = ""
        socket.puts("get db version")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> DB version OK".green)
            db_version = socket.gets.chomp
        end
        socket.close
        return db_version
    end

    def check_multiple_audio(tracks)
        return [] unless socket = get_connection
        socket.puts("check multiple audio")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Check audio OK".green)
            socket.puts(tracks)
            rs = socket.gets.chomp.split(" ")
        end
        socket.close
        return rs
    end

    def update_stats(rtrack)
        return unless socket = get_connection
        socket.puts("update stats")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Update stats OK".green)
            socket.puts(rtrack.to_s)
        end
        socket.close
    end

    def exec_sql(sql)
        return unless socket = get_connection
        socket.puts("exec sql")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Exec SQL OK".green)
            socket.puts(sql)
        end
        socket.close
    end

    def exec_batch(sql)
        return unless socket = get_connection
        socket.puts("exec batch")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Exec batch OK".green)
            socket.puts(sql.gsub(/\n/, '\n'))
        end
        socket.close
    end

    def renumber_play_list(rplist)
        return unless socket = get_connection
        socket.puts("renumber play list")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Renumber play list OK".green)
            socket.puts(rplist.to_s)
        end
        socket.close
    end

    def synchronize_resources
        return unless socket = get_connection
        resources = []
        socket.puts("synchronize resources")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Sync resources OK".green)
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                resources << str unless Utils::has_matching_file?(str) #File.exists?(str)
                str = socket.gets.chomp
            end
        end
        socket.close
        TRACE.debug("<--> Resources list received.".green)
        p resources
        return resources
    end

    def synchronize_sources
        return unless socket = get_connection
        files = []
        socket.puts("synchronize sources")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Sync sources OK".green)
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                files << str unless Utils::has_matching_file?(str)
                str = socket.gets.chomp
            end
        end
        socket.close
        TRACE.debug("<--> Sources list received.".green)
        return files
    end

    def rename_audio(rtrack, new_title)
        return "" unless socket = get_connection
        TRACE.debug("rename audio")
        socket.puts("rename audio")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Rename audio OK".green)
            socket.puts(rtrack.to_s)
            socket.puts(new_title)
        end
        socket.close
    end

    def get_audio_file(tasks, task_id, rtrack)
        return "" unless socket = get_connection
        TRACE.debug("send audio")
        socket.puts("send audio")
        file = ""
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Send audio OK".green)
            TRACE.debug("<--> Negociated block size is #{CFG.tx_block_size.to_s} bytes".brown)
            socket.puts(CFG.tx_block_size.to_s)
            if socket.gets.chomp.to_i == CFG.tx_block_size
                socket.puts(rtrack.to_s)
                size = socket.gets.chomp.to_i
                unless size == 0
                    file = socket.gets.chomp
                    if CFG.local_store?
                        FileUtils.mkpath(CFG.music_dir+File.dirname(file))
                        file = CFG.music_dir+file
                    else
                        file = CFG.rsrc_dir+"mfiles/"+File.basename(file)
                    end
                    download_file(tasks, task_id, file, size, socket)
                end
            end
        end
        socket.close
        return file
    end

    def get_file(file_name, tasks, task_id)
        return false unless socket = get_connection
        size = 0
        TRACE.debug("send file")
        socket.puts("send file")
        if socket.gets.chomp == "OK"
            TRACE.debug("<--> Send file OK".green)
            socket.puts(CFG.tx_block_size.to_s)
            if socket.gets.chomp.to_i == CFG.tx_block_size
                TRACE.debug("<--> Negociated block size is #{CFG.tx_block_size.to_s} bytes".brown)
                socket.puts(file_name)
                size = socket.gets.chomp.to_i
                download_file(tasks, task_id, Utils::replace_dir_name(file_name), size, socket) unless size == 0
            end
        end
        socket.close
        return size > 0
    end

    def download_file(tasks, task_id, file_name, file_size, socket)
        curr_size = 0
        status = Cfg::MSG_CONTINUE
        FileUtils.mkpath(File.dirname(file_name)) #unless File.directory?(File.dirname(file_name))
        f = File.new(file_name, "wb")
        while (data = socket.read(CFG.tx_block_size))
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
