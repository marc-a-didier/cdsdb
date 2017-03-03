
module EpsdfClient

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

        def check_multiple_audio(tracks)
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
                        network_task.task_owner.update_file_op(network_task.task_ref, curr_size, response['msg']['file_size'])
                    end
                    status = @streamer.parse_response['status'] == Epsdf::Protocol::MSG_OK
                    network_task.task_owner.end_file_op(network_task.task_ref, status)
                end
            end
            status
        end

        def upload_resource(network_task)
            status = false
            msg = setup_file_properties_msg(network_task.to_params)
            send_request(Request.new('upload resource', msg)) do |response|
                send_resource(@streamer, msg) do |curr_size|
                    network_task.task_owner.update_file_op(network_task.task_ref, curr_size, msg['file_size'])
                end
                status = @streamer.parse_response['status'] == Epsdf::Protocol::MSG_OK
                network_task.task_owner.end_file_op(network_task.task_ref, status)
            end if msg['file_size'] != 0
            status
        end
    end
end

EpsdfClient.setup
