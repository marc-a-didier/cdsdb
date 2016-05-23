#!/usr/bin/env ruby

require 'socket'

begin
    socket = TCPSocket.new('madAM1H', 32666)
rescue Errno::ECONNREFUSED => ex
    puts "Connection error (#{ex.class} : #{ex})."
end
puts(socket.gets.chomp)
socket.puts("reload hosts")
puts("Response: #{socket.gets.chomp}")
