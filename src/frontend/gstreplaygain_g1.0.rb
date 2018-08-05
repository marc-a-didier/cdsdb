
module GStreamer

    #
    # Computes the replay gain for an array of files.
    #
    # Returns an array of array containing gain & peak + 1 additional entry for the record gain & peak
    #
    def self.analyze(files)

        Trace.gst('Starting gain evaluation'.green)

        tpeak = tgain = rpeak = rgain = 0.0
        done  = false
        gains = []

        pipe = Gst::Pipeline.new('getgain')

        pipe.bus.add_watch do |bus, message|
            case message.type
                when Gst::MessageType::TAG
#                     p message.structure.name
#                     p message.structure.methods
#                     p message.structure.fields
#                     p message.structure.get_value('taglist').value.methods #get_value('replaygain-track-peak')
#                     p  message.structure.get_value('taglist').name
#                     l = message.structure.get_value('taglist').value
#                     p message.structure.get_value('taglist').value.get_double('replaygain-track-peak')
#                     p l.find('replaygain-track-peak')
#                     l.each_with_index { |tag, i| puts "i=#{i}, name=#{l.nth_tag_name(i)}, val=#{tag[i]}" }
#                     p message.structure.get_value('replaygain-track-peak').value
                    # returns [bool, double] : bool: found/not, double: val if found, 0.0 if not
                    if message.structure.get_value('taglist').value.get_double('replaygain-track-peak')[0]
                        tpeak = message.structure.get_value('taglist').value.get_double('replaygain-track-peak')[1]
                        tgain = message.structure.get_value('taglist').value.get_double('replaygain-track-gain')[1]

                        if message.structure.get_value('taglist').value.get_double('replaygain-album-peak')[0]
                            rpeak = message.structure.get_value('taglist').value.get_double('replaygain-album-peak')[1]
                            rgain = message.structure.get_value('taglist').value.get_double('replaygain-album-gain')[1]
                        end
                    end
#                     tpeak = message.structure['replaygain-track-peak'] if message.structure['replaygain-track-peak']
#                     tgain = message.structure['replaygain-track-gain'] if message.structure['replaygain-track-gain']
#                     rpeak = message.structure['replaygain-album-peak'] if message.structure['replaygain-album-peak']
#                     rgain = message.structure['replaygain-album-gain'] if message.structure['replaygain-album-gain']
#                     p message.structure
                when Gst::MessageType::EOS
                    # p message
                    done = true
                when Gst::MessageType::ERROR
                    p message
                    done = true
            end
            true
        end

        convertor = Gst::ElementFactory.make('audioconvert')
        resample  = Gst::ElementFactory.make('audioresample')
        rgana     = Gst::ElementFactory.make('rganalysis')
        sink      = Gst::ElementFactory.make('fakesink')

        decoder   = Gst::ElementFactory.make('decodebin')
        decoder.signal_connect(:pad_added) do |dbin, pad|
            pad.link(convertor.sinkpad)
            convertor >> resample >> rgana >> sink
        end

        source = Gst::ElementFactory.make('filesrc')

        rgana.num_tracks = files.size

        pipe.add(source, decoder, convertor, resample, rgana, sink)

        files.each do |file|
            done = false

#             pipe.clear
            pipe.set_state(Gst::State::NULL)
#             pipe.add(source, decoder, convertor, resample, rgana, sink)

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

            Trace.gst("Track gain=#{tgain}, peak=#{tpeak}".cyan)
        end
        rgana.set_state(Gst::State::NULL)

        gains << [rgain, rpeak]
        Trace.gst("Record gain=#{rgain}, peak=#{rpeak}".brown)

        return gains
    end
end