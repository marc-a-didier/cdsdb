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
        CFG.load if @parent.nil?
        CFG.set_local_mode # On va pas cascader les serveurs...

        Thread.abort_on_exception = true

        LOG.info("Server started")
        LOG.info("    Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}")
        LOG.info("    SQLite3 #{`sqlite3 --version`.chomp}")
        LOG.info("    Database #{CFG.db_version}")
        LOG.info("Server listening on host #{CFG.server} port #{CFG.port}.")

        # A bit of security...
        @allowed_hosts = []
        IO.foreach("/etc/hosts") { |line| @allowed_hosts << line.split(" ")[0] if line.match('^[0-9]') }
        hosts = "Allowed hosts :"
        @allowed_hosts.each { |host| hosts += " "+host }
        LOG.info(hosts)
    end

    def listen
        Signal.trap("TERM") {
            LOG.info("Server shutdown on TERM signal.")
            exit(0)
        }
        server = TCPServer.new('0.0.0.0', CFG.port)
        begin
            loop do #while (session = server.accept)
                Thread.start(server.accept) { |session|
                    if @allowed_hosts.include?(session.peeraddr[3])
                        req = session.gets.chomp
                        #puts("Request: #{req}")
                        begin
                            self.send(req.gsub(/ /, "_").to_sym, session)
                        rescue NoMethodError => ex
                            LOG.warn("Unknown request received (#{ex.class} : #{ex}).")
                        end
                    else
                        LOG.warn("Connection refused from #{session.peeraddr[3]}")
                        session.puts("Fucked up...")
                    end
                    session.close
                }
            end
        rescue Interrupt
            LOG.info("Server shutdown.")
        end
    end

    def send_audio(session)
        session.puts("OK")
        block_size = session.gets.chomp.to_i
        session.puts(block_size.to_s)
        rtrack = session.gets.chomp.to_i
        file = Utils::audio_file_exists(TrackInfos.new.get_track_infos(rtrack)).file_name
        LOG.info("Sending #{file} in #{block_size} bytes chunks to #{session.peeraddr(:hostname)[2]}")
        if file.empty?
            session.puts("0")
        else
            session.puts(File.size(file).to_s)
            session.puts(file.sub(CFG.music_dir, ""))
            File.open(file, "rb") { |f|
                while data = f.read(block_size)
                    session.write(data)
                    break if session.gets.chomp == Cfg::MSG_CANCELLED unless f.eof?
                end
            }
        end
    end

    # No more used... again...
    def check_single_audio(session)
        session.puts("OK")
        rtrack = session.gets.chomp.to_i
        session.puts(Utils::audio_file_exists(TrackInfos.new.get_track_infos(rtrack)).status.to_s)
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
            @parent.notify_played(session.gets.chomp.to_i, session.peeraddr(:hostname)[2])
        else
            DBUtils::update_track_stats(session.gets.chomp.to_i, session.peeraddr(:hostname)[2])
        end
    end

    def exec_sql(session)
        session.puts("OK")
        DBUtils::log_exec(session.gets.chomp, session.peeraddr(:hostname)[2])
    end

    def exec_batch(session)
        session.puts("OK")
        DBUtils::exec_batch(session.gets.chomp.gsub(/\\n/, "\n"), session.peeraddr(:hostname)[2])
    end

    def synchronize_resources(session)
        session.puts("OK")
        Cfg::DIR_NAMES[0..2].each { |name|
            Find::find(CFG.dirs[name]) { |file|
                session.puts(name+Cfg::FILE_INFO_SEP+file.sub(CFG.dirs[name], "")+
                                  Cfg::FILE_INFO_SEP+File::mtime(file).to_i.to_s) unless File.directory?(file)
            }
        }
        session.puts(Cfg::MSG_EOL)
    end

    def synchronize_sources(session)
        session.puts("OK")
        Find::find(CFG.sources_dir) { |file|
            next if file.match(/.*\.bzr/) # Skip hidden dir (.bzr for example...)
            session.puts("src"+Cfg::FILE_INFO_SEP+file.sub(CFG.sources_dir, "")+
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
            file_name = File::expand_path(CFG.database_dir+File::basename(file_name))
        elsif file_name.index("/Music/").nil? && file_name.index(CFG.rsrc_dir).nil?
            LOG.warn("Attempt to download file #{file_name} from #{session.peeraddr[3]}")
            session.puts("Fucked up...")
            return
        end
        LOG.info("Sending file #{file_name} in #{block_size} bytes chunks to #{session.peeraddr(:hostname)[2]}")
        session.puts(File.size(file_name).to_s)
        File.open(file_name, "rb") { |f|
            while data = f.read(block_size)
                session.write(data)
                break if session.gets.chomp == Cfg::MSG_CANCELLED unless f.eof?
            end
        }
    end

    def rename_audio(session)
        session.puts("OK")
        track_infos = TrackInfos.new.get_track_infos(session.gets.chomp.to_i)
        new_title   = session.gets.chomp
        file_name   = Utils::audio_file_exists(track_infos).file_name
        if file_name.empty?
            LOG.info("Attempt to rename inexisting track to #{new_title} [#{session.peeraddr(:hostname)[2]}]")
        else
            track_infos.track.stitle = new_title
            LOG.info("Track renaming [#{session.peeraddr(:hostname)[2]}]")
            Utils::tag_and_move_file(file_name, track_infos.build_access_infos)
        end
    end

    def get_db_version(session)
        session.puts("OK")
        session.puts(CFG.db_version)
    end

    def renumber_play_list(session)
        session.puts("OK")
        DBUtils::renumber_play_list(session.gets.chomp.to_i)
    end

end

MusicServer.new.listen if __FILE__ == $0
