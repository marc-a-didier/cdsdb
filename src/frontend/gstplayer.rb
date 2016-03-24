
#
# GStreamer player
#
# New instances must be provided with a subscriber that has to respond to 3 messages:
#   - gstplayer_eos() received when a stream has ended
#   - gstplayer_timer() received each half second
#   - gstplayer_level(stucture) received 25 times a second with the current rms and peak for each channel
#
#

module GStreamer

    class Player

        INTERVAL = 40000000  # Meter update interval (in nanoseconds) - 25Hz (50000000 -> 20Hz)

        LEFT_CHANNEL  = 0
        RIGHT_CHANNEL = 1
        CHANNELS      = [LEFT_CHANNEL, RIGHT_CHANNEL]

        def initialize(subscriber)
            @subscriber = subscriber
            @level_before_rg = true
        end

        def set_level_before_rg(level_before_rg)
            @level_before_rg = level_before_rg
            return self
        end

        def setup
            @timer = nil

            @gstbin = Gst::Pipeline.new

            @gstbin.bus.add_watch do |bus, message|
                case message.type
                    when Gst::Message::Type::ELEMENT
                        @subscriber.gstplayer_level(message.structure) if message.source.is_a?(Gst::ElementLevel)
                    when Gst::Message::EOS
                        stop
                        @subscriber.gstplayer_eos
                    when Gst::Message::ERROR
                        stop
                end
                true
            end


            @track_len = Gst::QueryDuration.new(Gst::Format::TIME)
            @track_pos = Gst::QueryPosition.new(Gst::Format::TIME)

            @convertor = Gst::ElementFactory.make('audioconvert')

            @level = Gst::ElementFactory.make('level')
            @level.interval = INTERVAL
            @level.message = true
            @level.peak_falloff = 100
            @level.peak_ttl = 200000000

            @rgain = Gst::ElementFactory.make('rgvolume')

            @sink = Gst::ElementFactory.make('autoaudiosink')

            @decoder = Gst::ElementFactory.make('decodebin')
            @decoder.signal_connect(:new_decoded_pad) do |dbin, pad, is_last|
                pad.link(@convertor.get_pad('sink'))
                if @level_before_rg
                    @convertor >> @level >> @rgain >> @sink
                else
                    @convertor >> @rgain >> @level >> @sink
                end
            end

            @source = Gst::ElementFactory.make('filesrc')

            return self
        end

        def set_ready(audio_file, replay_gain = 0.0, level_before_rg = true)
            @level_before_rg = level_before_rg

            # Must stop if track order changes as there already was a paused ready bin
            @gstbin.stop if paused?

            @rgain.fallback_gain = replay_gain

            @gstbin.clear
            @gstbin.add(@source, @decoder, @convertor, @level, @rgain, @sink)

            @source >> @decoder

            @source.location = audio_file
            @gstbin.pause
        end

        def start_track
            @gstbin.play

            sleep(0.001) while not playing?

            @gstbin.query(@track_len)

            @timer = Gtk.timeout_add(500) do
                @subscriber.gstplayer_timer
                true
            end
        end

        # This method must not be called while playing, the source
        # location becomes unavailable when gstreamer processes it.
        def audio_file
            return @source.location
        end

        def play
            @gstbin.play
        end

        def pause
            @gstbin.pause
        end

        def stop
            @gstbin.stop
            if @timer
                Gtk.timeout_remove(@timer)
                @timer = nil
            end
        end

        def playing?
            @gstbin.get_state[1] == Gst::STATE_PLAYING
        end

        def paused?
            @gstbin.get_state[1] == Gst::STATE_PAUSED
        end

        def active?
            return playing? || paused?
        end

        def get_state
            return @gstbin.get_state[1]
        end

        def get_replay_gain
            return @rgain.fallback_gain
        end

        # Returned value is an INTEGER in millisecond
        def duration
            return @track_len.parse[1]/Gst::MSECOND
        end

        # Returned value is an INTEGER in millisecond
        def play_position
            @gstbin.query(@track_pos)
            return @track_pos.parse[1]/Gst::MSECOND
        end

        def seek_set(value)
            @gstbin.seek(1.0, Gst::Format::Type::TIME,
                         Gst::Seek::FLAG_FLUSH | Gst::Seek::FLAG_KEY_UNIT,
                         Gst::Seek::TYPE_SET,
                         value * Gst::MSECOND,
                         Gst::Seek::TYPE_NONE, -1)
            # Wait at most 100 miliseconds for a state changes, this throttles the seek
            # events to ensure the playbin can keep up
            @gstbin.get_state(100 * Gst::MSECOND)
        end
    end
end
