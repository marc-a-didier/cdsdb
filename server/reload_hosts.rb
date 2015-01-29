#!/usr/bin/env ruby

require 'socket'

begin
    socket = TCPSocket.new('madD510', 32666)
rescue Errno::ECONNREFUSED => ex
    puts "Connection error (#{ex.class} : #{ex})."
end
socket.puts("reload hosts")
puts("Response: #{socket.gets.chomp}")
