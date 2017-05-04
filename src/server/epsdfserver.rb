#!/usr/bin/env ruby

require 'socket'
require 'fileutils'
require 'find'

require 'logger'

require 'sqlite3'
require 'taglib2'
require 'yaml'
require 'json'

require 'zlib'
require 'openssl'


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
require_relative '../shared/epsdf'

class EpsdfServer

    include Epsdf::Transfer
    include Epsdf::Server

    def initialize
        Cfg.remote = false # On va pas cascader les serveurs...

        Thread.abort_on_exception = true

        Log.info("Server started")
        Log.info("    Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}")
        Log.info("    SQLite3 #{`sqlite3 --version`.chomp}")
        Log.info("    Database #{DBIntf.db_version}")
        Log.info("Server listening on host #{Cfg.server} port #{Cfg.port}.")

        Signal.trap("TERM") { exit(0) }
        Signal.trap("HUP")  { }

        load_hosts
    end

    def reload_hosts(streamer, request)
        Log.info("Reloading hosts, request from #{streamer.hostname}")
        load_hosts
        return Epsdf::Protocol::MSG_OK
    end

    def is_alive(streamer, request)
        return "Yo man, i'm still alive..."
    end

    def get_db_version(streamer, request)
        return DBIntf.db_version
    end

    def has_resource(streamer, request)
        return File.exists?(Cfg.dir(request['params']['type'].to_sym)+request['params']['fname']) ? 1 : 0
    end

    def has_audio(streamer, request)
        audio_link = Audio::Link.new
        return request['params']['tracks'].map do |track|
            audio_link.reset.set_track_ref(track.to_i).setup_audio_file.status
        end
    end

    def exec_sql(streamer, request)
        DBUtils.log_exec(request['params']['sql'], streamer.hostname)
        return Epsdf::Protocol::MSG_OK
    end

    def exec_batch(streamer, request)
        DBUtils.exec_batch(request['params']['sql'], streamer.hostname)
        return Epsdf::Protocol::MSG_OK
    end

    def renumber_play_list(streamer, request)
        DBUtils.renumber_play_list(request['params']['plist'])
        return Epsdf::Protocol::MSG_OK
    end

    def rename_audio(streamer, request)
        audio_link = Audio::Link.new.set_track_ref(request['params']['rtrack'])
        file_name  = audio_link.setup_audio_file.file
        if file_name
            audio_link.track.stitle = request['params']['new_title']
            Log.info("Track renaming [#{streamer.hostname}]")
            audio_link.tag_and_move_file(file_name)
            return Epsdf::Protocol::MSG_OK
        else
            Log.info("Attempt to rename inexisting track to #{request['params']['new_title']} [#{streamer.hostname}]")
        end
        return Epsdf::Protocol::MSG_ERROR
    end

    def resources_list(streamer, request)
        dir = Cfg.dir(request['params']['type'].to_sym)
        return Find.find(dir).map do |file|
            File.directory?(file) ? nil : [file.sub(dir, ''), File.mtime(file).to_i]
        end.compact
    end

    def get_last_ids(streamer, request)
        [DBClasses::Artist, DBClasses::Record, DBClasses::Segment,
         DBClasses::Track, DBClasses::Label, DBClasses::Genre].map do |klass|
            [klass.name.split('::').last, klass.new.get_last_id]
        end.to_h
    end

    def server_info(streamer, request)
        return "CDsDB Server v#{Cfg::VERSION}n"+
               "Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}\n"+
               "SQLite3 #{`sqlite3 --version`}"+
               "Database v#{DBIntf.db_version}\n"
    end

    def download_resource(streamer, request)
        msg = setup_file_properties_msg(request['params'])

        if msg['file_size'] != 0
            streamer.send_stream(json_response(Epsdf::Protocol::MSG_OK, msg, request['started']))
            if send_resource(streamer, msg)
                return 'Download done'
            else
                return 'Download aborted'
            end
        else
            Log.info("Requested file '#{msg['file_name']}' not found [#{streamer.hostname}]")
            return 'Resource not found'
        end
    end

    def upload_resource(streamer, request)
        setup_resource_from_msg(request['params'])
        streamer.send_stream(json_response(Epsdf::Protocol::MSG_OK, Epsdf::Protocol::MSG_OK, request['started']))
        if receive_resource(streamer, request['params'])
            return 'Upload done'
        else
            return 'Upload aborted'
        end
    end
end

EpsdfServer.new.listen if __FILE__ == $0
