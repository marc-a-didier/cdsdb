#!/usr/bin/env ruby

require 'socket'
require 'fileutils'
require 'find'
require 'singleton'

require 'logger'

require 'sqlite3'
require 'taglib2'
require 'yaml'
require 'json'


require_relative '../shared/extenders'
require_relative '../shared/cfg'
require_relative '../shared/tracelog'
require_relative '../shared/dbintf'
require_relative '../shared/dbclassintf'
require_relative '../shared/utils'
require_relative '../shared/dbutils'
require_relative '../shared/audio'
require_relative '../shared/dbcache'
require_relative '../shared/dbcachelink'
require_relative '../shared/audiolink'


class MusicServer

    def initialize
        Cfg.server_mode = true
        Cfg.remote = false # On va pas cascader les serveurs...

        Thread.abort_on_exception = true

        Log.info("Server started")
        Log.info("    Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}")
        Log.info("    SQLite3 #{`sqlite3 --version`.chomp}")
        Log.info("    Database #{Cfg.db_version}")
        Log.info("Server listening on host #{Cfg.server} port #{Cfg.port}.")

        load_hosts
    end

    def load_hosts
        # A bit of security...
        @allowed_hosts = []
        IO.foreach("/etc/hosts") { |line| @allowed_hosts << line.split(" ")[0] if line.match('^[0-9]') }
        Log.info("Allowed hosts: #{@allowed_hosts.join(' ')}")
    end

    # Returned array of peeraddr: ["AF_INET", 46515, "jukebox", "192.168.1.123"]
    def ip_address(session)
        return session.peeraddr[3]
    end

    def hostname(session)
        return session.peeraddr(:hostname)[2]
    end


    def listen
        Signal.trap("TERM") {
            Log.info("Server shutdown on TERM signal.")
            exit(0)
        }
        Signal.trap("HUP") { Log.info("SIGHUP trapped and ignored.") }

        server = TCPServer.new('0.0.0.0', Cfg.port)
        begin
            loop do #while (session = server.accept)
                Thread.start(server.accept) do |session|
                    if @allowed_hosts.include?(ip_address(session)) # || ip_address(session).match(/^192\.168\.0\./)
                        meth, mode = session.gets.chomp.split(Cfg::SYNC_HDR)
                        meth = meth.gsub(/ /, '_').to_sym
                        # puts("Request: #{req}")
                        if self.respond_to?(meth)
                            session.puts(Cfg::MSG_OK)
                            self.send(meth, session, mode == "0" ? false : true)
                        else
                            Log.warn("Unknown request #{meth} received.")
                            session.puts(Cfg::MSG_ERROR)
                        end
                    else
                        Log.warn("Unlisted ip, connection refused from #{ip_address(session)}")
                        session.puts(Cfg::MSG_FUCKED)
                    end
                    session.close
                end
            end
        rescue Interrupt
            Log.info("Server shutdown.")
        end
    end

    #
    # Request to reload hosts from /etc/hosts
    #
    # IN : ---
    # OUT: ---
    #
    def reload_hosts(session, is_sync)
        Log.info("Reloading hosts, request from #{hostname(session)}")
        load_hosts
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Check is server responding
    #
    # IN : ---
    # OUT: string
    #
    def is_alive(session, is_sync)
        session.puts("Yo man, i'm still alive...")
        session.puts(Cfg::MSG_DONE) if is_sync
    end


    #
    # Check if tracks from list have their matching audio file on the file system
    #
    # IN : string of blank (' ') separated track PK
    # OUT: string of blank (' ') separated status, '1' for existence, '0' for non existence
    #
    def check_multiple_audio(session, is_sync)
        audio_link = Audio::Link.new
        rs = ""
        session.gets.chomp.split(" ").each { |track|
            rs << audio_link.reset.set_track_ref(track.to_i).setup_audio_file.status.to_s+" "
        }
        session.puts(rs)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Execute a single SQL statement on the db
    #
    # IN : string for SQL statement
    # OUT: ---
    #
    def exec_sql(session, is_sync)
        DBUtils.log_exec(session.gets.chomp, hostname(session))
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Execute multiple SQL statements separated by a ';' on the db
    #
    # IN : string for SQL statements
    # OUT: ---
    #
    def exec_batch(session, is_sync)
        DBUtils.exec_batch(session.gets.chomp.gsub(/\\n/, "\n"), hostname(session))
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Rename a track in the db and rename and retag it's matching audio file if any
    #
    # IN : track PK
    # IN : new track title
    # OUT: ---
    #
    def rename_audio(session, is_sync)
        audio_link = Audio::Link.new.set_track_ref(session.gets.chomp.to_i)
        new_title  = session.gets.chomp
        file_name  = audio_link.setup_audio_file.file
        if file_name
            audio_link.track.stitle = new_title
            Log.info("Track renaming [#{hostname(session)}]")
            audio_link.tag_and_move_file(file_name)
        else
            Log.info("Attempt to rename inexisting track to #{new_title} [#{hostname(session)}]")
        end
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Return the current db version the server is working against
    #
    # IN : ---
    # OUT: string of db version
    #
    def get_db_version(session, is_sync)
        session.puts(Cfg.db_version)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Renumber of a play list tracks
    #
    # IN : play list PK
    # OUT: ---
    #
    def renumber_play_list(session, is_sync)
        DBUtils.renumber_play_list(session.gets.chomp.to_i)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Get all files for a specific type of resource
    #
    # IN : resource_type
    # OUT: json string of array of array [ resource name, resource last modification time]
    #
    def resources_list(session, is_sync)
        # Get resource type to list
        resource_type = session.gets.chomp.to_sym

        # Cache dir name to avoid repeated calls
        dir = Cfg.dir(resource_type)

        # Resource dir is scanned and resource directory removed from file name using sub
        # cause we want to keep resources sub directories if any
        result = []
        Find.find(dir).map do |file|
            result << [file.sub(dir, ''), File.mtime(file).to_i] unless File.directory?(file)
        end
        session.puts(result.to_json)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Return a flag indicating the existence or not of a resource
    #
    # IN : resource type
    # IN : file name
    # OUT: '1' if exists, '0' if not
    #
    def has_resource(session, is_sync)
        # Hope the expression is parsed from left to right...
        file = Cfg.dir(session.gets.chomp.to_sym)+session.gets.chomp

        session.puts(File.exists?(file) ? '1' : '0')
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    #
    # Upload a resource to server. There's no special treatment for audio files
    # (:track resource), the file is put as it where asked to, db is not used to
    # build the file name from the track PK
    #
    # IN : resource type
    # IN : file name
    # IN : file size
    # repeated
    #   IN : data size
    #   IN : data block
    #   IN : status (continue/cancel)
    # OUT: ---
    #
    def upload_resource(session, is_sync)
        # Hope the expression is parsed from left to right...
        file = Cfg.dir(session.gets.chomp.to_sym)+session.gets.chomp

        FileUtils.mkpath(File.dirname(file)) unless Dir.exists?(File.dirname(file))

        status = Cfg::MSG_CONTINUE
        File.open(file, 'w') do |f|
            file_size = session.gets.chomp.to_i
            if file_size > 0
                while (size = session.gets.chomp.to_i) > 0 && status == Cfg::MSG_CONTINUE
                    f.write(session.read(size))
                    status = session.gets.chomp
                end
            end
        end
        FileUtils.rm(file) if status == Cfg::MSG_CANCELLED
        session.puts(Cfg::MSG_DONE) if is_sync
        Log.info("Received file #{file} [#{hostname(session)}]")
    end

    #
    # Send requested resource to client
    # If resource is :track, the client must send the track PK so the server
    # can build the file name from the db
    # In case of multiple format (.flac, .ogg) for a track, if the requested
    # block size is negative then the smallest file Otherwise it's the best quality one
    #
    # IN : resource type
    # IN : track PK only if resource is :track, resource file name otherwise
    # OUT: audio file name only if resource is :track
    # IN : transfer block size
    # OUT: file size
    # repeated:
    #   OUT: data block size
    #   OUT: data block
    #   IN : status (continue/cancel)
    # OUT: '0' block size
    #
    def download_resource(session, is_sync)
        # Get expected resource type to send
        resource_type = session.gets.chomp.to_sym

        # Set the server file name to send depending on the resource type
        case resource_type
            # When audio, client must send the track PK so the server can send back
            # the file name corresponding to the track
            when :track
                rtrack = session.gets.chomp.to_i
                file = Audio::Link.new.set_track_ref(rtrack).setup_audio_file.file
                session.puts(file.sub(Cfg.music_dir, ''))
            # Otherwise get file file name from the client
            when :db
                file = Cfg.database_dir+session.gets.chomp
            else
                file = Cfg.dir(resource_type)+session.gets.chomp
        end

        # Get the block size from client
        block_size = session.gets.chomp.to_i

        # If client prefers small size over quality, the requested block size is negative.
        Cfg.size_over_quality = block_size < 0
        block_size = block_size.abs

        if File.exists?(file)
            # Send the total file size to the client
            session.puts(File.size(file))

            # Loop sending blocks to client until complete or interrupted
            status = Cfg::MSG_CONTINUE
            File.open(file, "r") do |f|
                while (data = f.read(block_size)) && status == Cfg::MSG_CONTINUE
                    session.puts(data.size.to_s)
                    session.write(data)
                    status = session.gets.chomp
                end
            end
            Log.info("Sent file '#{file}' in #{block_size} bytes chunks [#{hostname(session)}]")
        else
            Log.info("Requested file '#{file}' not found [#{hostname(session)}]")
        end

        # Send 0 data size to client so it knows it's done
        session.puts('0')
        session.puts(Cfg::MSG_DONE) if is_sync
    end
end

MusicServer.new.listen if __FILE__ == $0
