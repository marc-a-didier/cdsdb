
PlayerData = Struct.new(:owner, :internal_ref, :uilink)

class PlayerWindow < TopWindow

    LEVEL_ELEMENT_NAME = "my_level_meter"
    MINIMUM_LEVEL = -60.0  # The scale range will be from this value to 0 dB, has to be negative
    POS_MIN_LEVEL = -1 * MINIMUM_LEVEL
    METER_WIDTH = 100 #70
    INTERVAL = 50000000    # How often update the meter? (in nanoseconds) - 20 times/sec in this case

    ELAPSED   = 0
    REMAINING = 1

    PLAY_STATE_BTN = { false => Gtk::Stock::MEDIA_PLAY, true => Gtk::Stock::MEDIA_PAUSE }

    PREFETCH_SIZE = 2


    SKIP_TO_NEXT = true
    DONT_SKIP    = false

    LAST_TRACK     = true
    NOT_LAST_TRACK = false


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

#         @player_data = nil

        # Intended to be a PlayerData array to pre-fetch tracks to play
        @queue = [nil]

        @file_preread = false

        @slider = @mc.glade[UIConsts::PLAYER_HSCALE]
        @lmeter = @mc.glade[UIConsts::PLAYER_PB_LEFT]
        @rmeter = @mc.glade[UIConsts::PLAYER_PB_RIGHT]

        # Min value for peak detected so far: -349.9999999218161

@max_l_peak = -60.0
@max_r_peak = -60.0
@max_l_rms  = -60.0
@max_r_rms  = -60.0

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

    def reset_player(notify)
        @tip_pix = nil

        if notify
            TRACE.debug("[nil]".red)
            if CFG.notifications?
                system("notify-send -t #{(CFG.notif_duration*1000).to_s} -i #{IMG_CACHE.default_record_file} 'CDs DB' 'End of play list'")
            end
        end

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
            @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = PLAY_STATE_BTN[playing?]
            @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = paused?
            @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = playing?
            @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
        else
            new_track(:start)
        end
        window.title = playing? ? "Player - [Playing]" : "Player - [Paused]"
    end

    def on_btn_stop
        return unless playing? || paused?
        stop
        @queue[0].owner.notify_played(@queue[0], LAST_TRACK, DONT_SKIP)
        reset_player(false)
        @queue.clear
    end

    def on_btn_next
        return if !playing? || paused? || !@queue[1]
        stop
        new_track(:next)
    end

    def on_btn_prev
        return if !playing? || paused? || !@queue[0].owner.has_more_tracks(false)
        stop
        new_track(:prev)
    end

    def play_track(player_data)
#         unless player_data
#             TRACE.debug("[nil]".red)
#             reset_player
#             if CFG.notifications?
#                 system("notify-send -t #{(CFG.notif_duration*1000).to_s} -i #{IMG_CACHE.default_record_file} 'CDs DB' 'End of play list'")
#             end
#             return
#         end

        # The status cache prevent the file name to be reloaded when selection is changed
        # in the track browser. So, from now, we may receive an empty file name but the
        # status is valid. If audio link is OK, we just have to find the file name for the track.

        # Not sure it's still true... Anyway, the caller MUST give a valid file to play, that's all!
        if player_data.uilink.audio_file.empty? #&& player_data.uilink.playable?
            player_data.uilink.setup_audio_file
            # player_data.uilink.search_audio_file
TRACE.debug("Player audio file was empty!".red)
        end

        # Restart player as soon as possible
#         reinit_player
        @source = Gst::ElementFactory.make("filesrc")

        @playbin.clear
        @playbin.add(@source, @decoder, @convertor, @level, @rgain, @sink)

        @source >> @decoder

        @source.location = player_data.uilink.audio_file
        @playbin.play
# puts("volume=#{@playbin.bin.get_property("volume")}")

        @was_playing = false # Probably useless


        # Debug info
        info = player_data.uilink.tags.nil? ? "[#{player_data.uilink.track.rtrack}" : "[dropped"
        TRACE.debug((info+", #{player_data.uilink.audio_file}]").cyan)

        # UI operations may be delayed
        @tip_pix = nil
        setup_hscale

        player_data.owner.started_playing(player_data)

        @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = player_data.uilink.html_track_title_no_track_num(false, " ")
        @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PAUSE
        @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = false
        @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = true
        @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
        if CFG.notifications?
            file_name = player_data.uilink.cover_file_name
            system("notify-send -t #{(CFG.notif_duration*1000).to_s} -i #{file_name} 'CDs DB now playing' \"#{player_data.uilink.html_track_title(true)}\"")
        end
    end

    def new_track(msg)
        start = Time.now.to_f
#         @player_data.owner.notify_played(@player_data) if @player_data

#         @mc.notify_played(@player_data.uilink) if has_ended
#
#         @player_data = @mc.get_next_track(true)
#
#         play_track
        # Test to lessen gap between tracks
        if msg == :stream_ended
#             play_track(@queue[1])
            @queue[1] ? play_track(@queue[1]) : reset_player(true)
            TRACE.debug("Elapsed: #{Time.now.to_f-start}")
            @queue[0].owner.notify_played(@queue[0], @queue[1].nil?, SKIP_TO_NEXT)
            @mc.notify_played(@queue[0].uilink)
            @queue.shift # Remove first entry, no more needed
        else
            case msg
                when :next
                    # We know it's not the last track because :next is not sent if no more track
                    @queue[0].owner.notify_played(@queue[0], NOT_LAST_TRACK, SKIP_TO_NEXT)
                    @queue.shift
                when :prev
                    @queue.clear
                    @queue[0] = @mc.get_next_track(false)
                when :start
                    @queue[0] = @mc.get_next_track(true)
            end

            # queue[0] may be nil only if play button is pressed while there's nothing to play
            play_track(@queue[0]) if @queue[0]
        end

        @queue.compact! # Remove nil entries
        if @queue[0]
#             @queue[0].owner.prefetch_tracks(@queue[0], PREFETCH_SIZE-@queue.size, PREFTECH_SIZE).each { |pdata| @queue << pdata }
            @queue[0].owner.prefetch_tracks(@queue, PREFETCH_SIZE)
        end

        @file_preread = false

#         TRACE.debug("Elapsed: #{Time.now.to_f-start}")
    end

    # Called by mc if any change made in the provider track list
    def refetch(track_provider)
        if @queue[0] && track_provider == @queue[0].owner
TRACE.debug("Player refetched".green)
            @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
#             track_provider.prefetch_tracks(@queue[0], PREFETCH_SIZE).each { |pdata| @queue << pdata }
            track_provider.prefetch_tracks(@queue, PREFETCH_SIZE)
        end
    end

    # Provider has been closed so remove all its remaining entries
    def unfetch(track_provider)
TRACE.debug("Player unfetched".brown)
        @queue.slice!(1, PREFETCH_SIZE) if @queue[0] && track_provider == @queue[0].owner
    end

    def init_player
        @seeking = false

        @playbin = Gst::Pipeline.new("levelmeter")
# p @playbin
#         bus = @playbin.bus
#         bus.add_watch do |bus, message|
        @playbin.bus.add_watch do |bus, message|
            #p message.type
            #p message.parse if message.respond_to?(:parse)
            case message.type
                when Gst::Message::Type::ELEMENT
                    if message.source.name == LEVEL_ELEMENT_NAME
# p message.structure["peak"]
                        lpeak = message.structure["peak"][0]
                        rpeak = message.structure["peak"][1]
                        lrms  = message.structure["rms"][0]
                        rrms  = message.structure["rms"][1]

#                         channels = message.structure["peak"].size
                        if lpeak < 0.0
                            peak = lpeak > -60.0 ? (90.0 * lpeak / 60.0) + 90.0 : 0.0
                        else
                            peak = 90.0+lpeak*10.0
                        end
#                         peak = lpeak > -60.0 ? (100.0 * lpeak / 60.0) + 100.0 : 0.0
#                         peak = message.structure["peak"][0] > -60.0 ? message.structure["peak"][0] + 100.0 : 0.0
#                         peak = 100.0 if peak > 100.0
                        @lmeter.fraction = peak/100.0

#                         peak = message.structure["peak"][1] > -60.0 ? message.structure["peak"][1] + 100.0 : 0.0
                        if rpeak < 0.0
                            peak = rpeak > -60.0 ? (90.0 * rpeak / 60.0) + 90.0 : 0.0
                        else
                            peak = 90.0+rpeak*10.0
                        end
#                         peak = rpeak > -60.0 ? (100.0 * rpeak / 60.0) + 100.0 : 0.0
#                         peak = 100.0 if peak > 100.0
                        @rmeter.fraction = peak/100.0

                        @max_l_peak = lpeak if lpeak > @max_l_peak
                        @max_r_peak = rpeak if rpeak > @max_r_peak

                        @max_l_rms = lrms if lrms > @max_l_rms
                        @max_r_rms = rrms if rrms > @max_r_rms
#                         2.times do |i|
#                         2.times do |i|
# #                             peak = message.structure["peak"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["peak"][i]) / POS_MIN_LEVEL).round + METER_WIDTH : 0
#                             peak = message.structure["peak"][i] > -60.0 ? (100.0 * message.structure["peak"][i] / 60.0) + 100.0 : 0.0
#                             #rms = message.structure["rms"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["rms"][i]) / POS_MIN_LEVEL).round + METER_WIDTH : 0
#                             peak = 100.0 if peak > 100.0
#                             if i == 0
#                                 @lmeter.fraction = peak/100.0
#                             else
#                                 @rmeter.fraction = peak/100.0
#                             end
#                         end
#                         channels = message.structure["peak"].size
#                         channels.times do |i|
#                             peak = message.structure["peak"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["peak"][i]) / POS_MIN_LEVEL).round + METER_WIDTH : 0
#                             #rms = message.structure["rms"][i] > MINIMUM_LEVEL ? (METER_WIDTH * (message.structure["rms"][i]) / POS_MIN_LEVEL).round + METER_WIDTH : 0
#                             peak = 100.0 if peak > 100.0
#                             if i == 0
#                                 @lmeter.fraction = peak/100.0
#                             else
#                                 @rmeter.fraction = peak/100.0
#                             end
#                         end
                    end
                when Gst::Message::EOS
                    stop
File.open("../../peaks.txt", "a") do |f|
f.puts("\n"+@queue[0].uilink.audio_file)
f.puts("max peak LEFT  = #{@max_l_peak}")
f.puts("max peak RIGHT = #{@max_r_peak}")
@max_l_peak = -60.0
@max_r_peak = -60.0
f.puts("max rms LEFT   = #{@max_l_rms}")
f.puts("max rms RIGHT  = #{@max_r_rms}")
@max_l_rms = -60.0
@max_r_rms = -60.0
end
                    new_track(:stream_ended)
                when Gst::Message::ERROR
                    stop
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

        @convertor = Gst::ElementFactory.make("audioconvert")

        @level = Gst::ElementFactory.make("level", LEVEL_ELEMENT_NAME)
        @level.interval = INTERVAL
        @level.message = true

        @rgain = Gst::ElementFactory.make("rgvolume")
#         @rgain.fallback_gain = -14
# p @rgain

        @sink = Gst::ElementFactory.make("autoaudiosink")

        @decoder = Gst::ElementFactory.make("decodebin")
        @decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
            pad.link(@convertor.get_pad("sink"))
            @convertor >> @level >> @rgain >> @sink
        }
    end

#     def reinit_player
#         @source = Gst::ElementFactory.make("filesrc")
#
# #         @decoder = Gst::ElementFactory.make("decodebin")
# #         @decoder.signal_connect(:new_decoded_pad) do | dbin, pad, is_last |
# #             pad.link(@convertor.get_pad("sink"))
# #             @convertor >> @level >> @sink
# #         end
#
#         @playbin.clear
#         @playbin.add(@source, @decoder, @convertor, @level, @sink)
#         @source >> @decoder
#         @was_playing = false
#     end

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

        @queue[0].owner.timer_notification(itime) if @queue[0].owner.respond_to?(:timer_notification)

        # If there's a next playable track in queue, read 512k of it in an attempt to make
        # it cached by the system and lose less time when skipping to it
        if @queue[1] && !@file_preread && @total_time-itime < 10000 && @queue[1].uilink.audio_status == AudioLink::OK
            File.open(@queue[1].uilink.audio_file) { |f| f.read(512*1024) }
            @file_preread = true
TRACE.debug("File pre-read for #{@queue[1].uilink.audio_file}".green)
        end
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
        @tip_pix = @queue[0].uilink.large_track_cover if @tip_pix.nil?
        tool_tip.set_icon(@tip_pix)
        text = @queue[0].uilink.html_track_title(true)+"\n\n"+format_time(@slider.value)+" / "+@mc.glade[UIConsts::PLAYER_LABEL_DURATION].label
        tool_tip.set_markup(text)
    end

    def playing?
        @playbin.get_state[1] == Gst::STATE_PLAYING
    end

    def paused?
        @playbin.get_state[1] == Gst::STATE_PAUSED
    end

end
