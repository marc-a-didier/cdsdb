#!/usr/bin/env ruby

require 'socket'
require 'fileutils'
require 'find'
require 'singleton'

require 'logger'

require 'sqlite3'
require 'taglib2'
require 'rexml/document'

require '../shared/uiconsts'
require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbclassintf'
require '../shared/utils'
require '../shared/dbutils'
require '../shared/trackinfos'

# Returned array of peeraddr: ["AF_INET", 46515, "jukebox", "192.168.1.123"]

class MusicServer

    def initialize(parent = nil)
        @parent = parent
        Cfg::instance.load if @parent.nil?
        Cfg::instance.set_local_mode # On va pas cascader les serveurs...

        Thread.abort_on_exception = true

        Log::instance.info("Server started")
        Log::instance.info("    Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}")
        Log::instance.info("    SQLite3 #{`sqlite3 --version`}")
        Log::instance.info("    Database #{Cfg::instance.db_version}")
        Log::instance.info("Server listening on host #{Cfg::instance.server} port #{Cfg::instance.port}.")

        # A bit of security...
        @allowed_hosts = []
        IO.foreach("/etc/hosts") { |line| @allowed_hosts << line.split(" ")[0] if line.match('^[0-9]') }
        hosts = "Allowed hosts :"
        @allowed_hosts.each { |host| hosts += " "+host }
        Log::instance.info(hosts)
    end

    def listen
        server = TCPServer.new(Cfg::instance.server, Cfg::instance.port)
        begin
            loop do #while (session = server.accept)
                Thread.start(server.accept) { |session|
                    if @allowed_hosts.include?(session.peeraddr[3])
                        req = session.gets.chomp
                        #puts("Request: #{req}")
                        begin
                            self.send(req.gsub(/ /, "_").to_sym, session)
                        rescue NoMethodError => ex
                            Log::instance.warn("Unknown request received (#{ex.class} : #{ex}).")
                        end
                    else
                        Log::instance.warn("Connection refused from #{session.peeraddr[3]}")
                        session.puts("Fucked up...")
                    end
                    session.close
                }
            end
        rescue Interrupt
            Log::instance.info("Server shutdown.")
        end
    end

    def send_audio(session)
        session.puts("OK")
        block_size = session.gets.chomp.to_i
        session.puts(block_size.to_s)
        rtrack = session.gets.chomp.to_i
        file = Utils::audio_file_exists(TrackInfos.new.get_track_infos(rtrack)).file_name
        Log::instance.info("Sending #{file} in #{block_size} bytes chunks to #{session.peeraddr[2]}")
        if file.empty?
            session.puts("0")
        else
            session.puts(File.size(file).to_s)
            session.puts(file.sub(Cfg::instance.music_dir, ""))
            f = File.new(file, "rb")
            while (data = f.read(block_size))
                session.write(data)
            end
            f.close
        end
    end

    def check_multiple_audio(session)
        session.puts("OK")
        track_mgr = TrackInfos.new
        rs = ""
        session.gets.chomp.split(" ").each { |track|
            rs << Utils::audio_file_exists(track_mgr.get_track_infos(track.to_i)).status.to_s+" "
        }
        session.puts(rs)
    end

    def update_stats(session)
        session.puts("OK")
        if @parent
            @parent.notify_played(session.gets.chomp.to_i, session.peeraddr[2])
        else
            DBUtils::update_track_stats(session.gets.chomp.to_i, session.peeraddr[2])
        end
    end

    def exec_sql(session)
        session.puts("OK")
        DBUtils::log_exec(session.gets.chomp, session.peeraddr[2])
    end

    def synchronize_resources(session)
        session.puts("OK")
        Cfg::DIR_NAMES[0..2].each { |name|
            Find::find(Cfg::instance.dirs[name]) { |file|
                session.puts(name+Cfg::FILE_INFO_SEP+file.sub(Cfg::instance.dirs[name], "")+
                                  Cfg::FILE_INFO_SEP+File::mtime(file).to_i.to_s) unless File.directory?(file)
            }
        }
        session.puts(Cfg::MSG_EOL)
    end

    def synchronize_sources(session)
        session.puts("OK")
        Find::find(Cfg::instance.sources_dir) { |file|
            next if file.match(/.*\.bzr/) # Skip hidden dir (.bzr for example...)
            session.puts("src"+Cfg::FILE_INFO_SEP+file.sub(Cfg::instance.sources_dir, "")+
                               Cfg::FILE_INFO_SEP+File::mtime(file).to_i.to_s) unless File.directory?(file)
        }
        session.puts(Cfg::MSG_EOL)
    end

    def send_file(session)
        session.puts("OK")
        block_size = session.gets.chomp.to_i
        session.puts(block_size.to_s)
        file_name = Utils::replace_dir_name(session.gets.chomp)
        if file_name.match(/.dwl$/)
            file_name.sub!(/.dwl$/, "") # Remove temp ext from client if downloading the database
            file_name = File::expand_path(Cfg::instance.database_dir+File::basename(file_name))
        elsif file_name.index("/Music/").nil? && file_name.index(Cfg::instance.rsrc_dir).nil?
            Log::instance.warn("Attempt to download file #{file_name} from #{session.peeraddr[3]}")
            session.puts("Fucked up...")
            return
        end
        Log::instance.info("Sending file #{file_name} in #{block_size} bytes chunks to #{session.peeraddr[2]}")
        session.puts(File.size(file_name).to_s)
        f = File.new(file_name, "rb")
        while (data = f.read(block_size))
            session.write(data)
        end
        f.close
    end

    def rename_audio(session)
        session.puts("OK")
        track_infos = TrackInfos.new.get_track_infos(session.gets.chomp.to_i)
        new_title   = session.gets.chomp
        file_name   = Utils::audio_file_exists(track_infos).file_name
        if file_name.empty?
            Log::instance.info("Attempt to rename inexisting track to #{new_title} [#{session.peeraddr[2]}]")
        else
            track_infos.track.stitle = new_title
            Log::instance.info("Track renaming [#{session.peeraddr[2]}]")
            Utils::tag_and_move_file(file_name, track_infos.build_access_infos)
        end
    end

    def get_db_version(session)
        session.puts("OK")
        session.puts(Cfg::instance.db_version)
    end

    def renumber_play_list(session)
        session.puts("OK")
        DBUtils::renumber_play_list(session.gets.chomp.to_i)
    end

end

MusicServer.new.listen if __FILE__ == $0
