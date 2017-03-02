#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'sqlite3'
require 'socket'
require 'logger'
require 'find'
require 'fileutils'

require 'zlib'
require 'openssl'

require '../shared/extenders'
require '../shared/cfg'
require '../shared/tracelog'
require '../shared/dbcachelink'
require '../shared/dbcache'
require '../shared/audio'
require '../shared/audiolink'
require '../shared/dbclassintf'
require '../shared/dbintf'

#
# SSL certificate/key generation:
# openssl req -x509 -newkey rsa:4096 -keyout cdsdb_key.pem -out cdsdb_cert.pem -days 365 -nodes
#

module Epsdf

    NetworkTask = Struct.new(:action,         # action type (download/upload)
                             :resource_type,  # type of file to work with
                             :resource_data,  # may be a file name or a cache link
                             :resource_owner, # call resource_owner.task_completed at the end
                             :task_owner,
                             :task_ref
                            ) do

        def to_params
            params = { 'type' => self.resource_type, 'block_size' => Cfg.tx_block_size }

            if self.resource_type == :track
                params['file_name'] = Audio::Link.new.set_track_ref(self.resource_data.track.rtrack).setup_audio_file.file
                params['rtrack'] = self.resource_data.track.rtrack
            elsif self.resource_type == :db
                params['file_name'] = DBIntf.build_db_name
            else
                params['file_name'] = self.resource_data
            end
            params['file_name'] = Cfg.relative_path(self.resource_type, params['file_name'])

            return params
        end
    end


    module Protocol
        VERSION  = '1.0.0'

        CLIENT = 'CDsDB Client'
        SERVER = 'CDsDB Server'

        STAT_CONT      = 'CONT'
        STAT_ABRT      = 'ABRT'

        MSG_OK         = 'OK'
        MSG_ASYNC_OK   = 'OK - ASYNC'
        MSG_ERROR      = 'Error'
        MSG_FUCKED     = 'Fucked up...'
        MSG_WELCOME    = 'E pericoloso sporgersi dalla finestra!'

        OPT_PLAIN      = 0
        OPT_COMP       = 1
        DEFAULT_DIALOG = OPT_PLAIN #OPT_COMP

        ASYNC_REQ   = 1

        ERR_NO_METH = 'Unknown request'

        ASYNC_PROCESSING = 'Async request queued'

        DEF_OPTIONS = { 'dialog' => DEFAULT_DIALOG }

        SSL_KEY  = File.join(ENV['HOME'], '.ssh', 'cdsdb_key.pem')
        SSL_CERT = File.join(ENV['HOME'], '.ssh', 'cdsdb_cert.pem')


        Header   = Struct.new(:source, :options, :version)
        Request  = Struct.new(:action, :params)
        Response = Struct.new(:status, :msg, :duration)

        def json_response(status, msg, started)
            return Response.new(status, msg, Time.now.to_f-started).to_h.to_json
        end

        def json_header(source, options = DEF_OPTIONS)
            return Header.new(source, options, VERSION).to_h.to_json
        end
    end

    class Streamer

        include Protocol

        attr_accessor :session, :header

        def initialize(session = nil)
            @session = session
            @header  = nil
        end

        def send_stream(json_data)
            if @header['options']['dialog'] & OPT_COMP == OPT_COMP
                data = Zlib::Deflate.deflate(json_data)
                @session.puts(data.size)
                @session.write(data)
            else
                @session.puts(json_data)
            end
            return self
        end

        def parse_header
            @header = JSON.parse(@session.gets.chomp)
            return self
        end

        def parse_stream
            if @header['options']['dialog'] & OPT_COMP == OPT_COMP
                size = @session.gets.chomp.to_i
                return JSON.parse(Zlib::Inflate.inflate(@session.read(size)))
            else
                return JSON.parse(@session.gets.chomp)
            end
        end

        def hand_shake
            @session.puts(json_header(CLIENT))
            return parse_header
        end

        def send_file(file_name, block_size, &block)
            status = STAT_CONT
            File.open(file_name, 'r') do |f|
                curr_size = 0
                while (data = f.read(block_size)) && status == STAT_CONT
                    curr_size += data.size
                    @session.puts(data.size.to_s)
                    @session.write(data)
                    if block_given?
                        status = yield(curr_size)
                        @session.puts(status)
                    else
                        status = @session.gets.chomp
                    end
                end
            end
            @session.puts('0')

            return status
        end

        def receive_file(file_name, &block)
            status = STAT_CONT
            File.open(file_name, 'w') do |f|
                curr_size = 0
                while (size = @session.gets.chomp.to_i) > 0 && status == STAT_CONT
                    curr_size += size
                    f.write(@session.read(size))
                    if block_given?
                        status = yield(curr_size)
                        @session.puts(status)
                    else
                        status = @session.gets.chomp
                    end
                end
            end
            return status
        end

        alias_method(:parse_response, :parse_stream)
        alias_method(:parse_request,  :parse_stream)
    end

    module Transfer

        include Protocol

        def setup_resource_from_msg(msg)
            if msg['type'].to_sym == :track
                msg['file_name'] = Audio::Link.new.set_track_ref(msg['rtrack']).setup_audio_file.file
            elsif msg['type'].to_sym == :db
                msg['file_name'] = DBIntf.build_db_name
            else
                msg['file_name'] = msg['file_name']
            end
            msg['file_name'] = Cfg.relative_path(msg['type'].to_sym, msg['file_name'])
        end

        def setup_file_properties_msg(params)
            msg = { 'file_name' => params['file_name'], 'file_size' => 0, 'mtime' => 0,
                    'type' => params['type'], 'rtrack' => params['rtrack'],
                    'block_size' => Cfg.tx_block_size }

            # if not coming from a network task, we have to build the file name
            setup_resource_from_msg(msg) unless params['file_name']

            file = Cfg.dir(msg['type'].to_sym)+msg['file_name']
            if File.exists?(file)
                # If small size is prefered over quality, the requested block size is negative.
                if self.is_a?(Server)
                    Cfg.size_over_quality = params['block_size'] < 0
                end
                msg['block_size'] = params['block_size'].abs
                msg['file_size'] = File.size(file)
                msg['mtime'] = File.mtime(file).to_i
            end

            return msg
        end

        def setup_file_request_msg(network_task)
            msg = { 'type' => network_task.resource_type, 'file_name' => nil, 'file_size' => nil,
                    'rtrack' => nil, 'block_size' => Cfg.tx_block_size }

            if network_task.resource_type == :track
                msg['rtrack'] = network_task.resource_data.track.rtrack
            else
                msg['file_name'] = network_task.resource_data
                network_task.resource_data += '.dwl' if network_task.resource_type == :db
            end

            msg['block_size'] = -Cfg.tx_block_size if network_task.resource_type == :track && Cfg.size_over_quality

            return msg
        end

        def send_resource(streamer, msg, &block)
            return streamer.send_file(Cfg.dir(msg['type'].to_sym)+msg['file_name'], msg['block_size'], &block) == STAT_CONT
        end

        def receive_resource(streamer, msg, &block)
            # file = Cfg.dir(msg['type'].to_sym)+msg['file_name']
            file = '/tmp/'+msg['file_name']

            FileUtils.mkpath(File.dirname(file)) unless Dir.exists?(File.dirname(file))

            status = streamer.receive_file(file, &block)
            if status == STAT_CONT
                File.utime(msg['mtime'], msg['mtime'], file)
            else
                FileUtils.rm(file)
            end
            #  Log.info("Received file #{file} [#{hostname(session)}]")
            return status == STAT_CONT
        end
    end

    module Client

        include Protocol

        def new_connection
            begin
                socket = TCPSocket.new('127.0.0.1', 32667) #(Cfg.server, Cfg.port)
                if Cfg.use_ssl?
                    expected_cert = OpenSSL::X509::Certificate.new(File.open(SSL_CERT))
                    ssl = OpenSSL::SSL::SSLSocket.new(socket)
                    ssl.sync_close = true
                    ssl.connect
                    if ssl.peer_cert.to_s != expected_cert.to_s
                        Trace.net("Unexpected certificate".red.bold)
                        return nil
                    end
                    @streamer.session = ssl
                else
                    @streamer.session = socket
                end

                if @streamer.session.gets.chomp == MSG_WELCOME
                    Trace.net("[#{'Connect'.magenta}] <-> [#{MSG_WELCOME.green}]")
                else
                    Trace.net("[#{'Connect'.magenta}] <-> [#{MSG_FUCKED.red.bold}]")
                    return nil
                end
                @streamer.hand_shake
                # puts(@streamer.header)
            rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError, OpenSSL::X509::CertificateError => ex
                Trace.net("connection error [#{ex.class.to_s.red.bold}]")
                return nil
            end
            return true
        end

        def post_request(request)
            if new_connection
                begin
                    request.params['async'] = 0 unless request.params['async']
                    response = @streamer.send_stream(request.to_h.to_json).parse_response
                    # puts(response)
                    return response
                rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => ex
                    Trace.net("connection error [#{ex.class.to_s.red.bold}]")
                end
            end
            return nil
        end

        def send_request(request, &block)
            started = Time.now.to_f
            if response = post_request(request)
                result = yield(response) #if block_given?
                Trace.net("[#{request['action'].magenta}] <-> [#{response['status'].green}]")
                Trace.net("Latency: %8.6f - Server: %8.6f" % [Time.now.to_f-started, response['duration']])
                @streamer.session.close
            end
            return result
        end

        def send_simple_request(action, params, &block)
            return send_request(Request.new(action, params), &block)
        end
    end

    module Server

        include Protocol

        def ip_address(session)
            return session.peeraddr[3]
        end

        def hostname(session)
            if Cfg.use_ssl?
                p session.peeraddr
                return session.peeraddr[2]
            else
                return session.peeraddr(:hostname)[2]
            end
        end

        def load_hosts
            # A bit of security... in case of plain text protocol
            @@allowed_hosts = IO.read('/etc/hosts').split("\n").map { |line| line.match(/^[0-9]/) ? line.split[0] : nil }.compact
            # Log.info("Allowed hosts: #{@@allowed_hosts.join(' ')}")
            puts("Allowed hosts: #{@@allowed_hosts.join(' ')}")
        end

        def listen
            load_hosts

            tcp_server = TCPServer.new('0.0.0.0', 32667) #Cfg.port)
            if Cfg.use_ssl?
                ssl_context = OpenSSL::SSL::SSLContext.new
                ssl_context.cert = OpenSSL::X509::Certificate.new(File.open(SSL_CERT))
                ssl_context.key = OpenSSL::PKey::RSA.new(File.open(SSL_KEY))
                ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, ssl_context)
                server = ssl_server
            else
                server = tcp_server
            end

            begin
                Kernel.loop do
                    begin
                        Thread.start(server.accept) do |session|
                            started = Time.now.to_f
                            p hostname(session)
                            if !Cfg.use_ssl? && !@@allowed_hosts.include?(ip_address(session))
                                # Log.warn("Unlisted ip, connection refused from #{ip_address(session)}")
                                session.puts(MSG_FUCKED)
                                sleep(1)
                                session.close
                                next # Exit thread, i hope...
                            end

                            streamer = Streamer.new(session)

                            session.puts(MSG_WELCOME)
                            streamer.parse_header
                            # puts(streamer.header)
                            streamer.session.puts(json_header(SERVER, streamer.header['options']))

                            request = streamer.parse_request
                            # puts(request)

                            meth = request['action'].gsub(/ /, '_').to_sym
                            if self.respond_to?(meth)
                                streamer.send_stream(json_response(MSG_ASYNC_OK, ASYNC_PROCESSING, started)) if request['params']['async'] == ASYNC_REQ
                                msg = self.send(meth, streamer, request)
                                streamer.send_stream(json_response(MSG_OK, msg, started)) unless request['params']['async'] == ASYNC_REQ
                            else
                                # Log.warn("Unknown request #{meth} received.")
                                streamer.send_stream(json_response(MSG_ERROR, ERR_NO_METH, started))
                            end
                            # Give client some time to read the response
                            sleep(1)
                            session.close
                        end
                    rescue OpenSSL::SSL::SSLError => ex
                        Trace.net("SSL: [#{ex.class.to_s.red.bold}]")
                        # Log.warrn(SSL: #{ex.class.to_s})
                    end
                end
            rescue Interrupt
                # Log.info("Server shutdown.")
            end
        end

    end

end

module TestClient

    class << self

        include Epsdf::Protocol
        include Epsdf::Transfer
        include Epsdf::Client

        def setup
            @streamer = Epsdf::Streamer.new
        end

        # WARNING: do NOT use return in callbacks otherwise the code after the yield is NOT executed!!!
        def reload_hosts
            send_simple_request('reload hosts', {}) { |response| response['msg'] }
        end

        def is_alive
            send_simple_request('is alive', {}) { |response| response['msg'] }
        end

        def get_server_db_version
            send_simple_request('get db version', {}) { |response| response['msg'] }
        end

        def check_resource(type, file_name)
            send_simple_request('has resource', { 'type' => type, 'fname' => file_name }) do |response|
                response['msg']
            end
        end

        def check_audio(tracks)
            send_simple_request('check multiple audio', { 'tracks' => tracks }) do |response|
                response['msg']
            end
        end

        def exec_sql(sql)
            send_simple_request('exec sql', { 'sql' => sql, 'async' => 1 }) do |response|
                response['msg']
            end
        end

        def exec_batch(sql)
            send_simple_request('exec batch', { 'sql' => sql, 'async' => 1 }) do |response|
                response['msg']
            end
        end

        def renumber_play_list(rplist)
            send_simple_request('renumber play list', { 'plist' => rplist, 'async' => 1 }) do |response|
                response['msg']
            end
        end

        def rename_audio(rtrack, new_title)
            send_simple_request('rename audio', { 'rtrack' => rtrack, 'new_title' => new_title, 'async' => 1 }) do |response|
                response['msg']
            end
        end

        def resources_to_update(resource_type)
            send_simple_request('resources list', { 'type' => resource_type.to_s }) do |response|
                response['msg'].map do |file, mtime|
                    (File.exists?(Cfg.dir(resource_type)+file) && File.mtime(Cfg.dir(resource_type)+file).to_i >= mtime) ? nil : file
                end.compact
            end
        end

        def get_last_ids
            send_simple_request('get last ids', {}) { |response| response['msg'] }
        end

        def server_info
            send_simple_request('server info', {}) { |response| response['msg'] }
        end

        def download_resource(network_task)
            status = false
            params = setup_file_request_msg(network_task)
            send_request(Request.new('download resource', params)) do |response|
                if response['msg']['file_size'] > 0
                    receive_resource(@streamer, response['msg']) do |curr_size|
                        # network_task.task_owner.update_file_op(network_task.task_ref, curr_size, msg['file_size'])
                        Epsdf::Protocol::STAT_CONT
                    end
                    status = @streamer.parse_response['status'] == Epsdf::Protocol::MSG_OK
                end
            end
            # network_task.task_owner.end_file_op(network_task.task_ref, status)
            status
        end

        def upload_resource(network_task)
            status = false
            msg = setup_file_properties_msg(network_task.to_params)
            send_request(Request.new('upload resource', msg)) do |response|
                send_resource(@streamer, msg) do |curr_size|
                    # network_task.task_owner.update_file_op(network_task.task_ref, curr_size, msg['file_size'])
                    Epsdf::Protocol::STAT_CONT
                end
                status = @streamer.parse_response['status'] == Epsdf::Protocol::MSG_OK
            end if msg['file_size'] != 0
            # network_task.task_owner.end_file_op(network_task.task_ref, status)
            status
        end
    end
end

class TestServer

    include Epsdf::Transfer
    include Epsdf::Server

    def reload_hosts(streamer, request)
        # Log.info("Reloading hosts, request from #{hostname(session)}")
        # load_hosts
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

    def check_multiple_audio(streamer, request)
        audio_link = Audio::Link.new
        return request['params']['tracks'].map do |track|
            audio_link.reset.set_track_ref(track.to_i).setup_audio_file.status
        end
    end

    def exec_sql(streamer, request)
        # DBUtils.log_exec(request['params']['sql'], hostname(streamer.session))
        return Epsdf::Protocol::MSG_OK
    end

    def exec_batch(streamer, request)
        # DBUtils.exec_batch(request['params']['sql'], hostname(streamer.session))
        return Epsdf::Protocol::MSG_OK
    end

    def renumber_play_list(streamer, request)
        # DBUtils.renumber_play_list(request['params']['plist'])
        return Epsdf::Protocol::MSG_OK
    end

    def rename_audio(streamer, request)
        audio_link = Audio::Link.new.set_track_ref(request['params']['rtrack'])
        file_name  = audio_link.setup_audio_file.file
        if file_name
            audio_link.track.stitle = request['params']['new_title']
            # Log.info("Track renaming [#{hostname(session)}]")
            # audio_link.tag_and_move_file(file_name)
            return Epsdf::Protocol::MSG_OK
        else
            # Log.info("Attempt to rename inexisting track to #{request['params']['new_title']} [#{hostname(session)}]")
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
            streamer.send_stream(json_response(Epsdf::Protocol::MSG_OK, msg, Time.now.to_f))
            if send_resource(streamer, msg)
                # Log.info("Sent file '#{file}' in #{block_size} bytes chunks [#{hostname(session)}]")
                return 'Download done'
            else
                # Log.info("Sent file '#{file}' in #{block_size} bytes chunks [#{hostname(session)}]")
                return 'Download aborted'
            end
        else
            # Log.info("Requested file '#{file}' not found [#{hostname(session)}]")
            return 'Resource not found'
        end
    end

    def upload_resource(streamer, request)
        setup_resource_from_msg(request['params'])
        streamer.send_stream(json_response(Epsdf::Protocol::MSG_OK, Epsdf::Protocol::MSG_OK, Time.now.to_f))
        if receive_resource(streamer, request['params'])
            # Log.info("Received file #{file} [#{hostname(session)}]")
            return 'Upload done'
        else
            # Log.info("Received file #{file} [#{hostname(session)}]")
            return 'Upload aborted'
        end
    end
end

Thread.abort_on_exception = true
TestClient.setup

case ARGV[0] || 'client'
when 'server' then TestServer.new.listen
when 'client'
    p TestClient.get_server_db_version
    p TestClient.check_resource(:flags, '13.svg')
    p TestClient.check_audio([1,2,3,4,5])
    p TestClient.resources_to_update(:flags)
    p TestClient.exec_sql("select * from xxx\nwhere zzz=uuu\nand\nyyy=ppp")
    p TestClient.exec_batch("select * from xxx\nwhere zzz=uuu\nand\nyyy=ppp;delete from ooo")
    p TestClient.get_last_ids
    p TestClient.server_info
    p TestClient.renumber_play_list(1)
    p TestClient.rename_audio(1, 'given new title...')
    p TestClient.reload_hosts
    p TestClient.is_alive
#     p TestClient.download_resource(Epsdf::NetworkTask.new(:download, :track, DBCache::Link.new.set_track_ref(2), nil, nil, nil))
#     p TestClient.upload_resource(Epsdf::NetworkTask.new(:upload, :track, DBCache::Link.new.set_track_ref(1), nil, nil, nil))
end
