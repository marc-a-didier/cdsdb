
require 'zlib'
require 'openssl'

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
        MSG_ASYNC_OK   = 'OK-ASYNC'
        MSG_ERROR      = 'Error'
        MSG_FUCKED     = 'Fucked up...'
        MSG_WELCOME    = 'E pericoloso sporgersi dalla finestra!'
        MSG_BYE        = 'Ciao bella!'

        OPT_PLAIN      = 0
        OPT_COMP       = 1
        DEFAULT_DIALOG = OPT_PLAIN #OPT_COMP

        ASYNC_REQ   = 1

        ERR_NO_METH = 'Unknown request'

        ASYNC_PROCESSING = 'Async request queued'

        DEF_OPTIONS = { 'dialog' => DEFAULT_DIALOG }

        SSL_KEY  = File.join(ENV['HOME'], '.ssh', 'cdsdb_key.pem')
        SSL_CERT = File.join(ENV['HOME'], '.ssh', 'cdsdb_cert.pem')

        DOWNLOAD_EXT = '.dwl'

        Header   = Struct.new(:source, :options, :version)
        Request  = Struct.new(:action, :params)
        Response = Struct.new(:status, :msg, :duration)

        def json_response(status, msg, started)
            return Response.new(status, msg, Time.now.to_f-started).to_h.to_json
        end

        def json_header(type, options = DEF_OPTIONS)
            source = { 'type' => type, 'hostname' => Cfg.hostname }
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

        def hostname
            return @header['source']['hostname']
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
                network_task.resource_data += DOWNLOAD_EXT if network_task.resource_type == :db
            end

            msg['block_size'] = -Cfg.tx_block_size if network_task.resource_type == :track && Cfg.size_over_quality

            return msg
        end

        def send_resource(streamer, msg, &block)
            status = streamer.send_file(Cfg.dir(msg['type'].to_sym)+msg['file_name'], msg['block_size'], &block)
            Log.info("Sent file '#{msg['file_name']}' in #{msg['block_size']} bytes chunks [#{streamer.hostname}]")
            return status == STAT_CONT
        end

        def receive_resource(streamer, msg, &block)
            file = Cfg.dir(msg['type'].to_sym)+msg['file_name']
            file += DOWNLOAD_EXT if msg['type'].to_sym == :db

            FileUtils.mkpath(File.dirname(file)) unless Dir.exists?(File.dirname(file))

            status = streamer.receive_file(file, &block)
            if status == STAT_CONT
                File.utime(msg['mtime'], msg['mtime'], file)
            else
                FileUtils.rm(file)
            end
            Log.info("Received file '#{msg['file_name']}' in #{msg['block_size']} bytes chunks [#{streamer.hostname}]")
            return status == STAT_CONT
        end
    end

    module Client

        include Protocol

        def new_connection
            begin
                socket = TCPSocket.new(Cfg.server, Cfg.port)

                # expected_cert = OpenSSL::X509::Certificate.new(IO.read(SSL_CERT))
                ssl = OpenSSL::SSL::SSLSocket.new(socket)
                ssl.sync_close = true
                ssl.connect
                if ssl.peer_cert.to_s != @expected_cert.to_s
                    Trace.net('Unexpected certificate'.red.bold)
                    return nil
                end
                @streamer.session = ssl

                msg = @streamer.session.gets.chomp
                if msg != MSG_WELCOME
                    Trace.net("[#{'Connect'.magenta}] <-> [#{msg.red.bold}]")
                    return nil
                # else
                #     Trace.net("[#{'Connect'.magenta}] <-> [#{msg.green}]")
                end
                @streamer.hand_shake
                # puts(@streamer.header)
            rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError, OpenSSL::X509::CertificateError => ex
                Trace.net("Connection: [#{ex.class.to_s.red.bold}]")
                return nil
            end
            return true
        end

        def post_request(request)
            if new_connection
                begin
                    request.params['async'] = false unless request.params['async']
                    response = @streamer.send_stream(request.to_h.to_json).parse_response
                    # puts(response)
                    return response
                rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => ex
                    Trace.net("Connection: [#{ex.class.to_s.red.bold}]")
                end
            end
            return nil
        end

        def send_request(request, &block)
            started = Time.now.to_f
            if response = post_request(request)
                result = yield(response) #if block_given?
                Trace.net("[#{request['action'].magenta}]<->[#{response['status'].green}]")
                Trace.net("L: %.3f - S: %.3f" % [Time.now.to_f-started, response['duration']])
                # @streamer.session.puts(MSG_BYE)
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

        def listen
            tcp_server = TCPServer.new('0.0.0.0', Cfg.port)

            ssl_context = OpenSSL::SSL::SSLContext.new
            ssl_context.cert = OpenSSL::X509::Certificate.new(IO.read(SSL_CERT))
            ssl_context.key = OpenSSL::PKey::RSA.new(IO.read(SSL_KEY))
            ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, ssl_context)

            begin
                Kernel.loop do
                    begin
                        Thread.start(ssl_server.accept) do |session|
                            started = Time.now.to_f

                            streamer = Streamer.new(session)

                            session.puts(MSG_WELCOME)
                            streamer.parse_header
                            # puts(streamer.header)
                            streamer.session.puts(json_header(SERVER, streamer.header['options']))

                            request = streamer.parse_request
                            request['started'] = started
                            # puts(request)

                            meth = request['action'].gsub(/ /, '_').to_sym
                            if self.respond_to?(meth)
                                streamer.send_stream(json_response(MSG_ASYNC_OK, ASYNC_PROCESSING, started)) if request['params']['async']
                                msg = self.send(meth, streamer, request)
                                streamer.send_stream(json_response(MSG_OK, msg, started)) unless request['params']['async']
                            else
                                Log.warn("Unknown request #{meth} received.")
                                streamer.send_stream(json_response(MSG_ERROR, ERR_NO_METH, started))
                            end
                            # Give client some time to read the response
                            sleep(1)
                            # session.gets # Should receive a ciao bella message
                            session.close
                        end
                    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError => ex
                        # Trace.net("SSL: [#{ex.class.to_s.red.bold}]")
                        Log.warrn("Connection: #{ex.class.to_s}")
                    end
                end
            rescue Interrupt
                Log.info("Server shutdown.")
            end
        end

    end

end
