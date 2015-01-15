
#
# GStreamer player
#
# New instances must be provided with a client that has to respond to 3 messages:
#   - process_message(:symbol) received when a stream has ended
#   - process_timer() received each half second
#   - process_level(stucture) received 25 times a second with the current rms and peak for each channel
#
#

class GstPlayer

    LEVEL_ELEMENT_NAME = "my_level_meter"
#     INTERVAL = 50000000    # How often update the meter? (in nanoseconds) - 20 times/sec in this case
    INTERVAL = 40000000    # How often update the meter? (in nanoseconds) - 25 times/sec in this case

    LEFT_CHANNEL  = 0
    RIGHT_CHANNEL = 1

    def initialize(client)
        @client = client
    end

    def setup
        @gstbin = Gst::Pipeline.new("levelmeter")

        @gstbin.bus.add_watch do |bus, message|
            case message.type
                when Gst::Message::Type::ELEMENT
                    if message.source.name == LEVEL_ELEMENT_NAME
                        @client.level_message(message.structure)
                    end
                when Gst::Message::EOS
                    stop
                    @client.process_message(:stream_ended)
                when Gst::Message::ERROR
                    stop
            end
            true
        end


        @track_len = Gst::QueryDuration.new(Gst::Format::TIME)
        @track_pos = Gst::QueryPosition.new(Gst::Format::TIME)
#         @track_pos = @gstbin.query_position(Gst::Format::TIME) # GStreamer 1.0
#         @track_len = @gstbin.query_duration(Gst::Format::TIME) # GStreamer 1.0

        @convertor = Gst::ElementFactory.make("audioconvert")

        @level = Gst::ElementFactory.make("level", LEVEL_ELEMENT_NAME)
        @level.interval = INTERVAL
        @level.message = true
        @level.peak_falloff = 100
        @level.peak_ttl = 200000000

        @rgain = Gst::ElementFactory.make("rgvolume")

        @sink = Gst::ElementFactory.make("autoaudiosink")

        @decoder = Gst::ElementFactory.make("decodebin")
        @decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
#         @decoder.signal_connect(:pad_added) { |dbin, pad| # GStreamer 1.0
            pad.link(@convertor.get_pad("sink"))
#             pad.link(@convertor.???) # GStreamer 1.0 Impossible to find the new way to do it...
            if GtkUI[GtkIDs::MM_PLAYER_LEVELBEFORERG].active?
                @convertor >> @level >> @rgain >> @sink
            else
                @convertor >> @rgain >> @level >> @sink
            end
        }

        @source = Gst::ElementFactory.make("filesrc")

        return self
    end

    def new_track(audio_file, replay_gain)
        @rgain.fallback_gain = replay_gain

        @gstbin.clear  # Doesn't exist in GStreamer 1.0
        @gstbin.add(@source, @decoder, @convertor, @level, @rgain, @sink)

        @source >> @decoder

system("vmtouch \"#{audio_file}\"")

        @source.location = audio_file
        @gstbin.play

        sleep(0.001) while not playing?

        @gstbin.query(@track_len)

        @timer = Gtk::timeout_add(500) { @client.timer_message; true }
    end

    def play
        @gstbin.play
    end

    def pause
        @gstbin.pause
    end

    def stop
        @gstbin.stop
        Gtk::timeout_remove(@timer)
        File.open(@source.location, "r") { |f| f.advise(:dontneed) }
    end

    def playing?
        @gstbin.get_state[1] == Gst::STATE_PLAYING
#         @gstbin.get_state(0)[1] == Gst::State::PLAYING # GStreamer 1.0
    end

    def paused?
        @gstbin.get_state[1] == Gst::STATE_PAUSED
#         @gstbin.get_state(0)[1] == Gst::State::PAUSED # GStreamer 1.0
    end

    def active?
        return playing? || paused?
    end

    def get_state
        return @gstbin.get_state[1]
    end


    # Returned value is a FLOAT in millisecond
    def play_time
        return @track_len.parse[1].to_f/Gst::MSECOND
    end

    # Returned value is an INTEGER in millisecond
    def play_position
        @gstbin.query(@track_pos)
        return (@track_pos.parse[1].to_f/Gst::MSECOND).to_i
    end

    def seek_set(value)
        @gstbin.seek(1.0, Gst::Format::Type::TIME,
                     Gst::Seek::FLAG_FLUSH.to_i |
                     Gst::Seek::FLAG_KEY_UNIT.to_i,
                     Gst::Seek::TYPE_SET,
                     (value * Gst::MSECOND).to_i,
                     Gst::Seek::TYPE_NONE, -1)
        # Wait at most 100 miliseconds for a state changes, this throttles the seek
        # events to ensure the playbin can keep up
        @gstbin.get_state(100 * Gst::MSECOND)
    end
end
