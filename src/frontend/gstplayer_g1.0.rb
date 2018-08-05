
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
                    when Gst::MessageType::ELEMENT
                        @subscriber.gstplayer_level(message.structure) if message.structure.name == 'level'
                    when Gst::MessageType::EOS
                        stop
                        @subscriber.gstplayer_eos
                    when Gst::MessageType::ERROR
                        stop
                end
                true
            end


            @convertor = Gst::ElementFactory.make('audioconvert')

            @level = Gst::ElementFactory.make('level')
            @level.interval = INTERVAL
            @level.message = true
            #@level.set_property('post-messages', true)
            @level.peak_falloff = 100
            @level.peak_ttl = 200000000

            @rgain = Gst::ElementFactory.make('rgvolume')

            @sink = Gst::ElementFactory.make('autoaudiosink')
            @sink.set_property('sync', true)

            @decoder = Gst::ElementFactory.make('decodebin')
            @decoder.signal_connect(:pad_added) do |dbin, pad|
                pad.link(@convertor.sinkpad)
                if @level_before_rg
                    @convertor >> @level >> @rgain >> @sink
                else
                    @convertor >> @rgain >> @level >> @sink
                end
            end

            @source = Gst::ElementFactory.make('filesrc')

            @gstbin.add(@source, @decoder, @convertor, @level, @rgain, @sink)

            @source >> @decoder

            return self
        end

        def set_ready(audio_file, replay_gain = 0.0, level_before_rg = true)
            @level_before_rg = level_before_rg

            # Must stop if track order changes as there already was a paused ready bin
            @gstbin.stop if paused?

            @rgain.fallback_gain = replay_gain

            @gstbin.set_state(Gst::State::NULL)

            @source.location = audio_file
            @gstbin.pause
        end

        def start_track
            @gstbin.play

            sleep(0.001) while not playing?

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
            @gstbin.set_state(Gst::State::NULL)
            if @timer
                Gtk.timeout_remove(@timer)
                @timer = nil
            end
        end

        def playing?
            @gstbin.get_state(0)[1] == Gst::State::PLAYING
        end

        def paused?
            @gstbin.get_state(0)[1] == Gst::State::PAUSED
        end

        def active?
            return playing? || paused?
        end

        def get_state
            return @gstbin.get_state(0)[1]
        end

        def get_replay_gain
            return @rgain.fallback_gain
        end

        # Returned value is an INTEGER in millisecond
        def duration
            return @gstbin.query_duration(Gst::Format::TIME)[1]/Gst::MSECOND
        end

        # Returned value is an INTEGER in millisecond
        def play_position
            return @gstbin.query_position(Gst::Format::TIME)[1]/Gst::MSECOND
        end

        def seek_set(value)
            @gstbin.seek_simple(Gst::Format::TIME,
                                Gst::SeekFlags::FLUSH | Gst::SeekFlags::KEY_UNIT,
                                value * Gst::MSECOND)
            # Wait at most 100 miliseconds for a state changes, this throttles the seek
            # events to ensure the playbin can keep up
            # @gstbin.get_state(100 * Gst::MSECOND)
        end
    end
end
