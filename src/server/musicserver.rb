#!/usr/bin/env ruby

require 'socket'
require 'fileutils'
require 'find'
require 'singleton'

require 'logger'

require 'sqlite3'
require 'yaml'

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
        hosts = "Allowed hosts :"
        @allowed_hosts.each { |host| hosts += " "+host }
        Log.info(hosts)
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

    def reload_hosts(session, is_sync)
        Log.info("Reloading hosts, request from #{hostname(session)}")
        load_hosts
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def is_alive(session, is_sync)
        session.puts("Yo man, i'm still alive...")
        session.puts(Cfg::MSG_DONE) if is_sync
    end


    def send_audio(session, is_sync)
        block_size = session.gets.chomp.to_i

        # If client prefers small size over quality, the requested block size is negative.
        Cfg.size_over_quality = block_size < 0
        block_size = block_size.abs

        session.puts(block_size.to_s)
        rtrack = session.gets.chomp.to_i
        file = Audio::Link.new.set_track_ref(rtrack).setup_audio_file.file
        if file
            Log.info("Sending #{file} in #{block_size} bytes chunks to #{hostname(session)}")
            session.puts(File.size(file).to_s)
            session.puts(file.sub(Cfg.music_dir, ""))
            File.open(file, "rb") { |f|
                while data = f.read(block_size)
                    session.write(data)
                    break if session.gets.chomp == Cfg::MSG_CANCELLED unless f.eof?
                end
            }
        else
            Log.warn("Requested file for track #{rtrack} not found")
            session.puts("0")
        end
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    # No more used... again...
    def check_single_audio(session, is_sync)
        rtrack = session.gets.chomp.to_i
        session.puts(Audio::Link.new.set_track_ref(rtrack).setup_audio_file.status.to_s)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def check_multiple_audio(session, is_sync)
        audio_link = Audio::Link.new
        rs = ""
        session.gets.chomp.split(" ").each { |track|
            rs << audio_link.reset.set_track_ref(track.to_i).setup_audio_file.status.to_s+" "
        }
        session.puts(rs)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

#     def update_stats(session, is_sync)
#         DBUtils.update_track_stats(session.gets.chomp.to_i, hostname(session))
#         session.puts(Cfg::MSG_DONE) if is_sync
#     end

    def exec_sql(session, is_sync)
        DBUtils.log_exec(session.gets.chomp, hostname(session))
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def exec_batch(session, is_sync)
        DBUtils.exec_batch(session.gets.chomp.gsub(/\\n/, "\n"), hostname(session))
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def synchronize_resources(session, is_sync)
        [:covers, :icons, :flags].each { |type|
            Find.find(Cfg.dir(type)) { |file|
                session.puts(type.to_s+Cfg::FILE_INFO_SEP+file.sub(Cfg.dir(type), "")+
                                       Cfg::FILE_INFO_SEP+File.mtime(file).to_i.to_s) unless File.directory?(file)
            }
        }
        session.puts(Cfg::MSG_EOL)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def synchronize_sources(session, is_sync)
        Find.find(Cfg.sources_dir) { |file|
            next if file.match(/.*\.bzr/) # Skip hidden dir (.bzr for example...)
            session.puts("src"+Cfg::FILE_INFO_SEP+file.sub(Cfg.sources_dir, "")+
                               Cfg::FILE_INFO_SEP+File.mtime(file).to_i.to_s) unless File.directory?(file)
        }
        session.puts(Cfg::MSG_EOL)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def send_file(session, is_sync)
        block_size = session.gets.chomp.to_i
        session.puts(block_size.to_s)
        file_name = Utils.replace_dir_name(session.gets.chomp)
        if file_name.match(/.dwl$/)
            file_name.sub!(/.dwl$/, "") # Remove temp ext from client if downloading the database
            file_name = File.expand_path(Cfg.database_dir+File.basename(file_name))
        elsif file_name.index("/Music/").nil? && file_name.index(Cfg.rsrc_dir).nil?
            Log.warn("Attempt to download file #{file_name} from #{ip_address(session)}")
            session.puts(Cfg::MSG_FUCKED)
            return
        end
        Log.info("Sending file #{file_name} in #{block_size} bytes chunks to #{hostname(session)}")
        session.puts(File.size(file_name).to_s)
        File.open(file_name, "rb") { |f|
            while data = f.read(block_size)
                session.write(data)
                break if session.gets.chomp == Cfg::MSG_CANCELLED unless f.eof?
            end
        }
#         session.puts(Cfg::MSG_DONE)
    end

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

    def get_db_version(session, is_sync)
        session.puts(Cfg.db_version)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

    def renumber_play_list(session, is_sync)
        DBUtils.renumber_play_list(session.gets.chomp.to_i)
        session.puts(Cfg::MSG_DONE) if is_sync
    end

end

MusicServer.new.listen if __FILE__ == $0
