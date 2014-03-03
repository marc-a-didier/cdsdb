#!/usr/bin/env ruby

require 'gst'
require 'sqlite3'
require 'find'


$peak = -100.0
$gain = -100.0

path = "../../db/"

# $db = SQLite3::Database.new(path+"cds6.0.db")

mainloop = GLib::MainLoop.new(nil, false)

pipe = Gst::Pipeline.new("getgain")

pipe.bus.add_watch do |bus, message|
#     p message.type
    #p message.parse if message.respond_to?(:parse)
    case message.type
#         when Gst::Message::Type::ELEMENT
#             p message
        when Gst::Message::Type::TAG
            p message.structure
            $peak = message.structure['replaygain-track-peak'] if message.structure['replaygain-track-peak']
            $gain = message.structure['replaygain-track-gain'] if message.structure['replaygain-track-gain']
        when Gst::Message::Type::EOS
            p message
#             mainloop.quit
    end
    true
end

convertor = Gst::ElementFactory.make("audioconvert")
resample = Gst::ElementFactory.make("audioresample")
rgana = Gst::ElementFactory.make("rganalysis")
sink = Gst::ElementFactory.make("fakesink")

decoder = Gst::ElementFactory.make("decodebin")
decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
    pad.link(convertor.get_pad("sink"))
    convertor >> resample >> rgana >> sink
}


source = Gst::ElementFactory.make("filesrc")

tracks = []
Find::find(ARGV[0]).each do |entry|
    tracks << entry if entry.match(/\.ogg$|\.flac$|\.mp3$/)
end

rgana.num_tracks = tracks.size
# rgana.locked_state = Gst::STATE_PLAYING
# rgana.set_locked_state(true)

mainloop.run

tracks.each { |track|
    pipe.clear
    pipe.add(source, decoder, convertor, resample, rgana, sink)

    source >> decoder

    source.location = track
    puts("Starting analysis for #{track}")
#     p source.location
#     puts("start...")
#     p pipe.get_state[1]
    pipe.set_state(Gst::STATE_PLAYING)
#     rgana.set_locked_state(true)
#     p pipe.get_state[1]
    begin
#         mainloop.run
    rescue Interrupt
    ensure
        pipe.stop
    end
    puts("gain=#{$gain}, peak=#{$peak}")
}
# pipe.stop
mainloop.quit
