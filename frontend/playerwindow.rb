
# PlayerData = Struct.new(:owner, :internal_ref, :fname, :rtrack, :rrecord, :irecsymlink)
PlayerData = Struct.new(:owner, :internal_ref, :uilink)

class PlayerWindow < TopWindow

    LEVEL_ELEMENT_NAME = "my_level_meter"
    MINIMUM_LEVEL = -60.0  # The scale range will be from this value to 0 dB, has to be negative
    METER_WIDTH = 100 #70
    INTERVAL = 50000000    # How often update the meter? (in nanoseconds) - 20 times/sec in this case

    ELAPSED   = 0
    REMAINING = 1


    def initialize(mc)
        super(mc, UIConsts::PLAYER_WINDOW)

        window.signal_connect(:delete_event) do
            stop if playing?
            @mc.notify_closed(self)
            true
        end

        @mc.glade[UIConsts::PLAYER_BTN_START].signal_connect(:clicked) { on_btn_play }
        @mc.glade[UIConsts::PLAYER_BTN_STOP].signal_connect(:clicked)  { on_btn_stop }
        @mc.glade[UIConsts::PLAYER_BTN_NEXT].signal_connect(:clicked)  { on_btn_next }
        @mc.glade[UIConsts::PLAYER_BTN_PREV].signal_connect(:clicked)  { on_btn_prev }

        @mc.glade[UIConsts::PLAYER_BTN_SWITCH].signal_connect(:clicked) { on_change_time_view }

        @pstate = {false => Gtk::Stock::MEDIA_PLAY, true => Gtk::Stock::MEDIA_PAUSE}
        @player_data = nil

        @track_infos = TrackInfos.new

        @slider = @mc.glade[UIConsts::PLAYER_HSCALE]
        @lmeter = @mc.glade[UIConsts::PLAYER_PB_LEFT]
        @rmeter = @mc.glade[UIConsts::PLAYER_PB_RIGHT]

        @time_view_mode = ELAPSED
        @total_time = 0

        # Tooltip cache. Inited when a new track starts.
        @tip_pix = nil

        init_player
    end

    def on_change_time_view
        @time_view_mode = @time_view_mode == ELAPSED ? REMAINING : ELAPSED
        update_hscale
    end

    def reset_player
        @player_data.owner.reset_player_track if @player_data
        @player_data = nil
        @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PLAY
        @seeking = false
        window.title = "Player - [Stopped]"
        @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = true
        @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = false
        @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = false
    end

    def on_btn_play
        if playing? || paused?
            playing? ? @playbin.pause : @playbin.play
            @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = @pstate[playing?]
            @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = paused?
            @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = playing?
            @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
        else
            next_track
        end
        window.title = playing? ? "Player - [Playing]" : "Player - [Paused]"
    end

    def on_btn_stop
        return if !playing? && !paused?
        stop
        @player_data.owner.timer_notification(-1) if @player_data.owner.respond_to?(:timer_notification)
        reset_player
    end

    def on_btn_next
        return if !playing? || paused? || !@player_data.owner.has_more_tracks(true)
        stop
        next_track
    end

    def on_btn_prev
        return if !playing? || paused? || !@player_data.owner.has_more_tracks(false)
        @player_data.owner.notify_played(@player_data)
        @player_data = @mc.get_next_track(false)
        stop
        play_track
    end

    def play_track
puts @player_data ? "[#{@player_data.uilink.track.rtrack}, #{@player_data.uilink.audio_file}]" : "[nil]"
        if @player_data.nil?
            reset_player
            if Cfg::instance.notifications?
                system("notify-send -t #{(Cfg::instance.notif_duration*1000).to_s} -i #{ImageCache::instance.default_record_file} 'CDs DB' 'End of play list'")
            end
        else
#             @track_infos.from_tags(@player_data.uicache.music_file)
#             @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = UIUtils::tags_html_track_title(@track_infos, " ")
            @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = @player_data.uilink.html_track_title(false, " ")
            @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PAUSE
            @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = false
            @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = true
            @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
            reinit_player
            @source.location = @player_data.uilink.audio_file
            @playbin.play
            setup_hscale
            @tip_pix = @player_data.uilink.large_track_cover
            if Cfg::instance.notifications?
                file_name = @player_data.uilink.cover_file_name
                system("notify-send -t #{(Cfg::instance.notif_duration*1000).to_s} -i #{file_name} 'CDs DB now playing' \"#{@player_data.uilink.html_track_title(true)}\"")
            end
        end
    end

    def next_track(has_ended = false)
        @player_data.owner.notify_played(@player_data) if @player_data

        @mc.notify_played(@player_data.uilink) if has_ended

        @player_data = @mc.get_next_track(true)

        play_track
    end

    def init_player
        @seeking = false

        @minimum_level_positive = -1 * MINIMUM_LEVEL # convert that only once, to save CPU power
        @playbin = Gst::Pipeline.new("levelmeter")
        bus = @playbin.bus
        bus.add_watch do |bus, message|
            #p message.type
            #p message.parse if message.respond_to?(:parse)
            case message.type
                when Gst::Message::EOS
                    stop
                    next_track(true)
                when Gst::Message::ERROR
                    stop
                when Gst::Message::Type::ELEMENT
                    if message.source.name == LEVEL_ELEMENT_NAME
                        channels = message.structure["peak"].size
                        channels.times do |i|
                            peak = message.structure["peak"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["peak"][i]) / @minimum_level_positive).round + METER_WIDTH : 0
                            #rms = message.structure["rms"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["rms"][i]) / @minimum_level_positive).round + METER_WIDTH : 0
                            peak = 100.0 if peak > 100.0
                            if i == 0
                                @lmeter.fraction = peak/100.0
                            else
                                @rmeter.fraction = peak/100.0
                            end
                        end
                    end
            end
            true
        end

        @track_pos = Gst::QueryPosition.new(Gst::Format::TIME)
        @slider.signal_connect(:button_press_event) do
            @seeking = true
            @was_playing = playing?
            @playbin.pause if playing?
            false # Means the parent handler has to be called
        end
        @slider.signal_connect(:button_release_event) do
            @seeking = false
            seek_set
            @playbin.play if @was_playing
            false # Means the parent handler has to be called
        end
        @seek_handler = @slider.signal_connect(:value_changed) { seek if @seeking; false }
            #seek((@slider.value * Gst::MSECOND).to_i)
            #false
        #}
        #@seek_handler = @slider.signal_connect(:value_changed) { puts @slider.value.to_s; seek_set; seek; }
    end

    def reinit_player
        @source = Gst::ElementFactory.make("filesrc")

        @convertor = Gst::ElementFactory.make("audioconvert")

        @level = Gst::ElementFactory.make("level", LEVEL_ELEMENT_NAME)
        @level.interval = INTERVAL
        @level.message = true

        @sink = Gst::ElementFactory.make("autoaudiosink")

        @decoder = Gst::ElementFactory.make("decodebin")
        @decoder.signal_connect(:new_decoded_pad) do | dbin, pad, is_last |
            pad.link(@convertor.get_pad("sink"))
            @convertor >> @level >> @sink
        end

        @playbin.clear
        @playbin.add(@source, @decoder, @convertor, @level, @sink)
        @source >> @decoder
        @was_playing = false
    end

    def setup_hscale
        sleep(0.01) while not playing? # We're threaded and async

        track_len = Gst::QueryDuration.new(Gst::Format::TIME)
        @playbin.query(track_len)
        @total_time = track_len.parse[1].to_f/Gst::MSECOND
        @slider.set_range(0.0, @total_time)
        @total_time = @total_time.to_i
        @mc.glade[UIConsts::PLAYER_LABEL_DURATION].label = format_time(@total_time)

        @playbin.query(@track_pos)
        #@mc.glade[UIConsts::PLAYER_HSCALE].set_range(0.0, track_len.parse[1].to_f/Gst::MSECOND)
        #@slider.update_policy = Gtk::UPDATE_DISCONTINUOUS
#        duration = track_len.parse[1].to_f/Gst::MSECOND
#         @mc.glade[UIConsts::PLAYER_HSCALE].adjustment = Gtk::Adjustment.new(0.0,
#                                                                             0.0, duration,
#                                                                             duration/100.0,
#                                                                             duration/10.0, duration/1000.0)
#         @mc.glade[UIConsts::PLAYER_HSCALE].adjustment = Gtk::Adjustment.new(0.0,
#                                                                             0.0, duration,
#                                                                             0.0, # step inc duration/100.0,
#                                                                             duration/10.0, # page inc
#                                                                             0.0) # page size

        @timer = Gtk::timeout_add(500) { update_hscale; true }
    end

    def update_hscale
        #return if !playing? || @seeking
        return if @seeking || (!playing? && !paused?)
#puts "Updating."
        @playbin.query(@track_pos)

        itime = (@track_pos.parse[1].to_f/Gst::MSECOND).to_i
        #@slider.signal_handler_block(@seek_handler)
        @slider.value = itime #@track_pos.parse[1].to_f/Gst::MSECOND
        #@slider.signal_handler_unblock(@seek_handler)

        show_time(itime)
#         if @time_view_mode == ELAPSED
#             @mc.glade[UIConsts::PLAYER_LABEL_POS].label = format_time(itime)
#         else
#             @mc.glade[UIConsts::PLAYER_LABEL_POS].label = "-"+format_time(@total_time-itime)
#         end

        @player_data.owner.timer_notification(itime) if @player_data.owner.respond_to?(:timer_notification)
        #show_tooltip(@tool_tip) if @tool_tip && @tooltip.visible?
    end

    def seek_set
        @playbin.seek(1.0, Gst::Format::Type::TIME,
                      Gst::Seek::FLAG_FLUSH.to_i |
                      Gst::Seek::FLAG_KEY_UNIT.to_i,
                      Gst::Seek::TYPE_SET,
                      (@slider.value * Gst::MSECOND).to_i,
                      Gst::Seek::TYPE_NONE, -1)
        # Wait at most 100 miliseconds for a state changes, this throttles the seek
        # events to ensure the playbin can keep up
        @playbin.get_state(100 * Gst::MSECOND)
    end

    def seek
#puts "seeking"
#        @mc.glade[UIConsts::PLAYER_LABEL_POS].label = format_time(@slider.value)
        show_time(@slider.value)
    end

    def show_time(itime)
        if @time_view_mode == ELAPSED
            @mc.glade[UIConsts::PLAYER_LABEL_POS].label = format_time(itime)
        else
            @mc.glade[UIConsts::PLAYER_LABEL_POS].label = "-"+format_time(@total_time-itime)
        end
    end

    def format_time(itime)
        return sprintf("%02d:%02d", itime/60000, (itime % 60000)/1000)
    end

    def stop
        @playbin.stop
        Gtk::timeout_remove(@timer)
    end

    def show_tooltip(si, tool_tip)
        tool_tip.set_icon(@tip_pix)
        text = @player_data.uilink.html_track_title(true)+"\n\n"+format_time(@slider.value)+" / "+@mc.glade[UIConsts::PLAYER_LABEL_DURATION].label
        tool_tip.set_markup(text)
    end

    def playing?
        @playbin.get_state[1] == Gst::STATE_PLAYING
    end

    def paused?
        @playbin.get_state[1] == Gst::STATE_PAUSED
    end

end
