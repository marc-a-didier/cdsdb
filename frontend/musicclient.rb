# !/usr/bin/env ruby

require 'socket'

class MusicClient

    def get_connection
        begin
            socket = TCPSocket.new(Cfg::instance.server, Cfg::instance.port)
        rescue Errno::ECONNREFUSED => ex
            puts "Connection error (#{ex.class} : #{ex})."
            Cfg::instance.set_local_mode
            UIUtils::show_message("Can't connect to server #{Cfg::instance.server} on port #{Cfg::instance.port}.\n
                                   Config reset to local browsing mode.", Gtk::MessageDialog::ERROR)
            return nil
        end
        return socket
    end


    # Not used...
    def check_single_audio(rtrack)
        socket = TCPSocket.new(Cfg::instance.server, Cfg::instance.port)
        socket.puts("check single audio")
        if socket.gets.chomp == "OK"
            puts "OK"
            socket.puts(rtrack.to_s)
            exists = socket.gets.chomp.to_i
            p exists
        end
        socket.close
        return exists
    end

    def get_server_db_version
        return "" unless socket = get_connection
puts("get db version")
        db_version = ""
        socket.puts("get db version")
        if socket.gets.chomp == "OK"
            puts "OK"
            db_version = socket.gets.chomp
        end
        socket.close
        return db_version
    end

    def check_multiple_audio(tracks)
        return [] unless socket = get_connection
        socket.puts("check multiple audio")
        if socket.gets.chomp == "OK"
            puts "OK"
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
            puts "OK"
            socket.puts(rtrack.to_s)
        end
        socket.close
    end

    def exec_sql(sql)
        return unless socket = get_connection
        socket.puts("exec sql")
        if socket.gets.chomp == "OK"
            puts "OK"
            socket.puts(sql)
        end
        socket.close
    end

    def renumber_play_list(rplist)
        return unless socket = get_connection
        socket.puts("renumber play list")
        if socket.gets.chomp == "OK"
            puts "renumber play list OK"
            socket.puts(rplist.to_s)
        end
        socket.close
    end

    def synchronize_resources
        return unless socket = get_connection
        resources = []
        socket.puts("synchronize resources")
        if socket.gets.chomp == "OK"
            puts "sync resources: OK"
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                resources << str unless Utils::has_matching_file?(str) #File.exists?(str)
                str = socket.gets.chomp
            end
        end
        socket.close
        puts "Resources list received."
p resources
        return resources
    end

    def synchronize_sources
        return unless socket = get_connection
        files = []
        socket.puts("synchronize sources")
        if socket.gets.chomp == "OK"
            puts "sync sources: OK"
            str = socket.gets.chomp
            until str == Cfg::MSG_EOL
                files << str unless Utils::has_matching_file?(str)
                str = socket.gets.chomp
            end
        end
        socket.close
        puts "Sources list received."
        return files
    end

    def rename_audio(rtrack, new_title)
        return "" unless socket = get_connection
puts("rename audio")
        socket.puts("rename audio")
        if socket.gets.chomp == "OK"
puts "OK"
            socket.puts(rtrack.to_s)
            socket.puts(new_title)
        end
        socket.close
    end

    def get_audio_file(tasks, task_id, rtrack)
        return "" unless socket = get_connection
        puts("send audio")
        socket.puts("send audio")
        file = ""
        if socket.gets.chomp == "OK"
            puts "OK"
            puts(Cfg::instance.tx_block_size.to_s)
            socket.puts(Cfg::instance.tx_block_size.to_s)
            if socket.gets.chomp.to_i == Cfg::instance.tx_block_size
                socket.puts(rtrack.to_s)
                size = socket.gets.chomp.to_i
                #p size
                unless size == 0
                    file = socket.gets.chomp
                    if Cfg::instance.local_store?
                        FileUtils.mkpath(Cfg::instance.music_dir+File.dirname(file))
                        file = Cfg::instance.music_dir+file
                    else
                        file = Cfg::instance.rsrc_dir+"mfiles/"+File.basename(file)
                    end
                    download_file(tasks, task_id, file, size, socket)
                end
                #p file
            end
        end
        socket.close
        return file
    end

    def get_file(file_name, tasks, task_id)
        return false unless socket = get_connection
        size = 0
        puts("send file")
        socket.puts("send file")
        if socket.gets.chomp == "OK"
            puts "OK"
            puts(Cfg::instance.tx_block_size.to_s)
            socket.puts(Cfg::instance.tx_block_size.to_s)
            if socket.gets.chomp.to_i == Cfg::instance.tx_block_size
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
        FileUtils.mkpath(File.dirname(file_name)) #unless File.directory?(File.dirname(file_name))
        f = File.new(file_name, "wb")
        while (data = socket.read(Cfg::instance.tx_block_size))
            curr_size += data.size
            tasks.update_file_op(task_id, curr_size, file_size)
            f.write(data)
            #sleep(0.5)
        end
        tasks.end_file_op(task_id, file_name)
        f.close
    end

end
