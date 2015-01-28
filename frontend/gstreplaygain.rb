
module GStreamer

    #
    # Computes the replay gain for an array of files.
    #
    # Returns an array of array containing gain & peak + 1 additional entry for the record gain & peak
    #
    def self.analyze(files)

        TRACE.debug("Starting gain evaluation".green)

        tpeak = tgain = rpeak = rgain = 0.0
        done  = error = false
        gains = []

        pipe = Gst::Pipeline.new("getgain")

        pipe.bus.add_watch do |bus, message|
            case message.type
                when Gst::Message::Type::TAG
                    tpeak = message.structure['replaygain-track-peak'] if message.structure['replaygain-track-peak']
                    tgain = message.structure['replaygain-track-gain'] if message.structure['replaygain-track-gain']
                    rpeak = message.structure['replaygain-album-peak'] if message.structure['replaygain-album-peak']
                    rgain = message.structure['replaygain-album-gain'] if message.structure['replaygain-album-gain']
                    # p message.structure
                when Gst::Message::Type::EOS
                    # p message
                    done = true
                when Gst::Message::Type::ERROR
                    p message
                    done = true
                    error = true
            end
            true
        end

        convertor = Gst::ElementFactory.make("audioconvert")
        resample  = Gst::ElementFactory.make("audioresample")
        rgana     = Gst::ElementFactory.make("rganalysis")
        sink      = Gst::ElementFactory.make("fakesink")

        decoder   = Gst::ElementFactory.make("decodebin")
        decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
            pad.link(convertor.get_pad("sink"))
            convertor >> resample >> rgana >> sink
        }

        source = Gst::ElementFactory.make("filesrc")

        rgana.num_tracks = files.size

        files.each do |file|
            done = false

            pipe.clear
            pipe.add(source, decoder, convertor, resample, rgana, sink)

            source >> decoder

            source.location = file
            begin
                pipe.play
                while !done
                    Gtk.main_iteration while Gtk.events_pending?
                    sleep(0.01)
                end
            rescue Interrupt
            ensure
                rgana.set_locked_state(true)
                pipe.stop
            end

            gains << [tgain, tpeak]

            TRACE.debug("Track gain=#{tgain}, peak=#{tpeak}".cyan)
        end
        rgana.set_state(Gst::STATE_NULL)

        gains << [rgain, rpeak]
        TRACE.debug("Record gain=#{rgain}, peak=#{rpeak}".brown)

        return gains
    end
end