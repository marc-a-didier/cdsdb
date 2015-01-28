#!/usr/bin/env ruby

require 'socket'
require 'fileutils'
require 'find'
require 'singleton'

require 'logger'

require 'sqlite3'
# require 'taglib2'
require 'yaml'
# require 'rexml/document'

require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbclassintf'
require '../shared/utils'
require '../shared/dbutils'
require '../shared/audio'
require '../shared/dbcache'
require '../shared/dbcachelink'
require '../shared/audiolink'
# require '../shared/trackinfos'


class MusicServer

    def initialize
        CFG.load
        CFG.server_mode = true
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

    # Returned array of peeraddr: ["AF_INET", 46515, "jukebox", "192.168.1.123"]
    def ip_address(session)
        return session.peeraddr[3]
    end

    def hostname(session)
        return session.peeraddr(:hostname)[2]
    end


    def listen
        Signal.trap("TERM") {
            LOG.info("Server shutdown on TERM signal.")
            exit(0)
        }
        Signal.trap("HUP") { LOG.info("SIGHUP trapped and ignored.") }

        server = TCPServer.new('0.0.0.0', CFG.port)
        begin
            loop do #while (session = server.accept)
                Thread.start(server.accept) { |session|
                    if @allowed_hosts.include?(ip_address(session)) # || ip_address(session).match(/^192\.168\.0\./)
                        req = session.gets.chomp
                        # puts("Request: #{req}")
                        begin
                            self.send(req.gsub(/ /, "_").to_sym, session)
                        rescue NoMethodError => ex
                            LOG.warn("Unknown request received (#{ex.class} : #{ex}).")
                        end
                    else
                        LOG.warn("Connection refused from #{ip_address(session)}")
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
        file = Audio::Link.new.set_track_ref(rtrack).setup_audio_file.file
        LOG.info("Sending #{file} in #{block_size} bytes chunks to #{hostname(session)}")
        if file
            session.puts(File.size(file).to_s)
            session.puts(file.sub(CFG.music_dir, ""))
            File.open(file, "rb") { |f|
                while data = f.read(block_size)
                    session.write(data)
                    break if session.gets.chomp == Cfg::MSG_CANCELLED unless f.eof?
                end
            }
        else
            session.puts("0")
        end
    end

    # No more used... again...
    def check_single_audio(session)
        session.puts("OK")
        rtrack = session.gets.chomp.to_i
        session.puts(Audio::Link.new.set_track_ref(rtrack).setup_audio_file.status.to_s)
    end

    def check_multiple_audio(session)
        session.puts("OK")
        audio_link = Audio::Link.new
        rs = ""
        session.gets.chomp.split(" ").each { |track|
            rs << audio_link.reset.set_track_ref(track.to_i).setup_audio_file.status.to_s+" "
        }
        session.puts(rs)
    end

    def update_stats(session)
        session.puts("OK")
        DBUtils.update_track_stats(session.gets.chomp.to_i, hostname(session))
    end

    def exec_sql(session)
        session.puts("OK")
        DBUtils.log_exec(session.gets.chomp, hostname(session))
    end

    def exec_batch(session)
        session.puts("OK")
        DBUtils.exec_batch(session.gets.chomp.gsub(/\\n/, "\n"), hostname(session))
    end

    def synchronize_resources(session)
        session.puts("OK")
        [:covers, :icons, :flags].each { |type|
            Find::find(CFG.dir(type)) { |file|
                session.puts(type.to_s+Cfg::FILE_INFO_SEP+file.sub(CFG.dir(type), "")+
                                       Cfg::FILE_INFO_SEP+File.mtime(file).to_i.to_s) unless File.directory?(file)
            }
        }
        session.puts(Cfg::MSG_EOL)
    end

    def synchronize_sources(session)
        session.puts("OK")
        Find::find(CFG.sources_dir) { |file|
            next if file.match(/.*\.bzr/) # Skip hidden dir (.bzr for example...)
            session.puts("src"+Cfg::FILE_INFO_SEP+file.sub(CFG.sources_dir, "")+
                               Cfg::FILE_INFO_SEP+File.mtime(file).to_i.to_s) unless File.directory?(file)
        }
        session.puts(Cfg::MSG_EOL)
    end

    def send_file(session)
        session.puts("OK")
        block_size = session.gets.chomp.to_i
        session.puts(block_size.to_s)
        file_name = Utils.replace_dir_name(session.gets.chomp)
        if file_name.match(/.dwl$/)
            file_name.sub!(/.dwl$/, "") # Remove temp ext from client if downloading the database
            file_name = File.expand_path(CFG.database_dir+File.basename(file_name))
        elsif file_name.index("/Music/").nil? && file_name.index(CFG.rsrc_dir).nil?
            LOG.warn("Attempt to download file #{file_name} from #{ip_address(session)}")
            session.puts("Fucked up...")
            return
        end
        LOG.info("Sending file #{file_name} in #{block_size} bytes chunks to #{hostname(session)}")
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
        audio_link = Audio::Link.new.set_track_ref(session.gets.chomp.to_i)
        new_title  = session.gets.chomp
        file_name  = audio_link.setup_audio_file.file
        if file_name
            audio_link.track.stitle = new_title
            LOG.info("Track renaming [#{hostname(session)}]")
            audio_link.tag_and_move_file(file_name)
        else
            LOG.info("Attempt to rename inexisting track to #{new_title} [#{hostname(session)}]")
        end
    end

    def get_db_version(session)
        session.puts("OK")
        session.puts(CFG.db_version)
    end

    def renumber_play_list(session)
        session.puts("OK")
        DBUtils.renumber_play_list(session.gets.chomp.to_i)
    end

end

MusicServer.new.listen if __FILE__ == $0
