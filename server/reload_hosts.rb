#!/usr/bin/env ruby

require 'socket'

begin
    socket = TCPSocket.new('127.0.0.1', 32666)
rescue Errno::ECONNREFUSED => ex
    puts "Connection error (#{ex.class} : #{ex})."
end
socket.puts("reload hosts")
puts("Respons: #{socket.gets.chomp}")
