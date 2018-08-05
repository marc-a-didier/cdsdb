
class PlayerWindow < TopWindow

    MIN_LEVEL     = -80.0  # The scale range will be from this value to 0 dB, has to be negative
    POS_MIN_LEVEL = -1 * MIN_LEVEL

    METER_WIDTH = 449.0 # Offset start 10 pixels idem end
    IMAGE_WIDTH = 469.0

    ELAPSED   = 0
    REMAINING = 1

    PLAY_STATE_BTN = { false => Gtk::Stock::MEDIA_PLAY, true => Gtk::Stock::MEDIA_PAUSE }

    PREFETCH_SIZE = 2

    Y_OFFSETS = [16, 28]

    DIGIT_HEIGHT = 20
    DIGIT_WIDTH  = 12

    STD_PEAK_COLOR = Gdk::Color.new(0xffff, 0xffff, 0xffff)
    OVR_PEAK_COLOR = Gdk::Color.new(0xffff, 0x0000, 0x0000)


    def initialize(mc)
        super(mc, GtkIDs::PLAYER_WINDOW)

        window.signal_connect(:delete_event) do
            terminate
            @mc.notify_closed(self)
            true
        end

        @meter = GtkUI[GtkIDs::PLAYER_IMG_METER]
        @meter.signal_connect(:realize) { |widget| meter_setup }

        @counter = GtkUI[GtkIDs::PLAYER_IMG_COUNTER]
        # @counter.set_size_request(11*DIGIT_WIDTH, DIGIT_HEIGHT)
        @counter.signal_connect(:realize) { |widget| counter_setup }

        GtkUI[GtkIDs::PLAYER_BTN_START].signal_connect(:clicked) { on_btn_play }
        GtkUI[GtkIDs::PLAYER_BTN_STOP].signal_connect(:clicked)  { on_btn_stop }
        GtkUI[GtkIDs::PLAYER_BTN_NEXT].signal_connect(:clicked)  { on_btn_next }
        GtkUI[GtkIDs::PLAYER_BTN_PREV].signal_connect(:clicked)  { on_btn_prev }

        # GtkUI[GtkIDs::PLAYER_BTN_SWITCH].signal_connect(:clicked) { on_change_time_view }

        GtkUI[GtkIDs::PLAYER_LABEL_TITLE].label = ""

        # TrackRefs array: [0] is the current track, [1..PREFETCH_SIZE-1] are the next tracks to play
        @queue = []

        @slider = GtkUI[GtkIDs::PLAYER_HSCALE]

        @time_view_mode = ELAPSED
        @total_time = 0

        # Tooltip cache. Inited when a new track starts.
        @tip_pix = nil

        # Two instances of GStreamerPlayer are created, playbin being the actual player
        # while readybin is in charge of prefecthing the next track to be played.
        # When playbin finishes its track, readybin becomes the playbin and
        # the playbin becomes the readybin.
        @playbin  = GStreamer::Player.new(self).setup
        @readybin = GStreamer::Player.new(self).setup

        # Handling of slider button draging
        @was_playing = false # Only used to remember the state of the player when seeking
        @seek_handler = nil # Signal is only connected when needed, that is when draging the slider button
        @slider.signal_connect(:button_press_event) do
            if @playbin.active?
                @seek_handler = @slider.signal_connect(:value_changed) { show_time(@slider.value); false }
                @was_playing = @playbin.playing?
                @playbin.pause if @was_playing
                false # Means the parent handler has to be called
            else
                # Don't call parent handler so clicking on button has no effect
                true
            end
        end
        @slider.signal_connect(:button_release_event) do
            if @seek_handler
                @playbin.seek_set(@slider.value)
                @playbin.play if @was_playing
                @slider.signal_handler_disconnect(@seek_handler)
                @seek_handler = nil
            end
            false # Means the parent handler has to be called
        end
    end


    ###########################################################################
    # User interface setup and utilities
    ###########################################################################

    # Build the backgroud image of the level meter when the GTK image is realized
    def meter_setup
        # Get the pixmap from the gtk image on the meter window
        @mpix = Gdk::Pixmap.new(@meter.window, IMAGE_WIDTH, 52, -1) # 52 = 16*2+8*2+1*4

        # Get the image graphic context and set the foreground color to white
        @gc = Gdk::GC.new(@meter.window)

        # Get the meter image, unlit and lit images from their files
        scale   = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"k14-scaleH.png")
        @dark   = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"k14-meterH0.png")
        @bright = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"k14-meterH1.png")

        # Start splitting the meter image to build the definitive bitmap as the scale image
        # is not the final image onto which we draw
        # draw_pixbuf(gc, pixbuf, src_x, src_y, dest_x, dest_y, width, height, dither, x_dither, y_dither)
        @mpix.draw_pixbuf(nil, scale, 0, 4, 0, 0, 469, 16, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 16, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, scale, 0, 0, 0, 24, 469, 4, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 28, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, scale, 0, 0, 0, 36, 469, 16, Gdk::RGB::DITHER_NONE, 0, 0)
        # At this point, @mpix contains the definitive bitmap

        # Draw the bitmap on screen
        @meter.set(@mpix, nil)
    end

    def counter_setup
        @dpix = Gdk::Pixmap.new(@counter.window, 11*DIGIT_WIDTH, DIGIT_HEIGHT, -1)

        @digits = []
        10.times { |i| @digits[i] = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"#{i}digit.png", width: DIGIT_WIDTH, height: DIGIT_HEIGHT) }
        @digits[10] = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"unlitdigit.png", width: DIGIT_WIDTH, height: DIGIT_HEIGHT)
        @digits[11] = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"colondigit.png", width: DIGIT_WIDTH, height: DIGIT_HEIGHT)
        @digits[12] = GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+"minusdigit.png", width: DIGIT_WIDTH, height: DIGIT_HEIGHT)

        reset_counter
    end

    def reset_counter
        11.times do |i|
            if i == 2 || i == 8
                @dpix.draw_pixbuf(nil, @digits[11], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            elsif i == 5
                @dpix.draw_pixbuf(nil, @digits[12], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            else
                @dpix.draw_pixbuf(nil, @digits[10], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            end
        end
        @counter.set(@dpix, nil)
    end

    def time_to_digits(stime)
        i = 0
        stime.each_byte do |ch|
            if ch != 45 && ch != 58 # Skip always lit chars (- & :)
                if (i == 0 || i == 6) && ch == 48
                    @dpix.draw_pixbuf(nil, @digits[10], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
                else
                    @dpix.draw_pixbuf(nil, @digits[ch-48], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
                end
            end
            i += 1
        end
        @counter.set(@dpix, nil)
    end

    def set_window_title
        msg = case @playbin.get_state #[1]
#             when Gst::STATE_PLAYING then "Playing"
#             when Gst::STATE_PAUSED  then "Paused"
            when Gst::State::PLAYING then "Playing"
            when Gst::State::PAUSED  then "Paused"
            else "Stopped"
        end
        window.title = "Player - [#{msg}]"
    end

    def on_change_time_view
        @time_view_mode = @time_view_mode == ELAPSED ? REMAINING : ELAPSED
        update_hscale
    end

    def on_btn_play
        if @playbin.active?
            @playbin.playing? ? @playbin.pause : @playbin.play
            GtkUI[GtkIDs::PLAYER_BTN_START].stock_id = PLAY_STATE_BTN[@playbin.playing?]
            GtkUI[GtkIDs::TTPM_ITEM_PLAY].sensitive = @playbin.paused?
            GtkUI[GtkIDs::TTPM_ITEM_PAUSE].sensitive = @playbin.playing?
            GtkUI[GtkIDs::TTPM_ITEM_STOP].sensitive = true
        else
            new_track(:start)
        end
        set_window_title
    end

    def on_btn_stop
        return unless @playbin.active?
        terminate
        @queue[0].owner.notify_played(@queue[0], :stop)
        reset_player(false)
        @queue.clear
    end

    def on_btn_next
        return if !@playbin.active? || !@queue[1]
        terminate
        new_track(:next)
    end

    def on_btn_prev
        return if !@playbin.active? || !@queue[0].owner.has_track(@queue[0], :prev)
        terminate
        new_track(:prev)
    end

    # Set the UI to initial state (stopped) and display an end of play notification if wanted
    def reset_player(notify)
        @tip_pix = nil

        if notify
            Trace.gst('empty queue'.red)
            if Cfg.notifications
                system("notify-send -t #{(Cfg.notif_duration*1000).to_s} -i #{XIntf::Image::Cache.default_record_file} 'CDsDB' 'End of play list'")
            end
        end

        # Reset button states
        GtkUI[GtkIDs::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PLAY
        set_window_title
        GtkUI[GtkIDs::TTPM_ITEM_PLAY].sensitive = true
        GtkUI[GtkIDs::TTPM_ITEM_PAUSE].sensitive = false
        GtkUI[GtkIDs::TTPM_ITEM_STOP].sensitive = false

        # Clear level meter
        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 16, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)
        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 28, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)
        @meter.set(@mpix, nil)

        # Clear title, time and slider
        reset_counter
        GtkUI[GtkIDs::PLAYER_LABEL_TITLE].label = ""
        @slider.value = 0.0
    end


    ###########################################################################
    # Player control methods
    ###########################################################################

    # Stop all bins
    def terminate
        @playbin.stop
        @readybin.stop
    end

    def build_info_string(player_data, replay_gain, gain_src = '')
        return "#{player_data.xlink.audio_file.sub(Cfg.music_dir, '')} [#{player_data.xlink.tags.nil? ? player_data.xlink.track.rtrack : 'dropped'}, #{gain_src}#{replay_gain}]"
    end

    # Initialize the next track to be played in paused state in the ready bin
    def set_ready(player_data)
        # audio_file may only be nil if the cache has been cleared
        # while there were ready to play tracks in the queue.
        unless player_data.xlink.audio_file
            player_data.xlink.setup_audio_file
            Trace.gst('link audio file was empty!'.red.bold)
        end

        # Check if the ready bin already has the same audio file
        # If the file is the same we also have to check that the ready bin is in paused state
        if player_data.xlink.audio_file != @readybin.audio_file || !@readybin.paused?
#             Trace.gst("readying #{player_data.xlink.audio_file}".brown)

            # Can't use replay gain if track has been dropped.
            # Replay gain should work if tags are set in the audio file
            replay_gain = 0.0
            gain_src = 'NONE '
            if player_data.xlink.tags.nil?
                if player_data.xlink.use_record_gain? && GtkUI[GtkIDs::MM_PLAYER_USERECRG].active?
                    replay_gain = player_data.xlink.record.igain/Audio::GAIN_FACTOR
                    gain_src = 'RECORD '
#                     Trace.gst("RECORD gain: #{replay_gain}".brown)
                elsif GtkUI[GtkIDs::MM_PLAYER_USETRKRG].active?
                    replay_gain = player_data.xlink.track.igain/Audio::GAIN_FACTOR
                    gain_src = 'TRACK '
#                     Trace.gst("TRACK gain #{replay_gain}".brown)
                end
            end

            # It may happen that we have to wait for a track being downloaded from server
            sleep(0.1) while not player_data.xlink.playable?

            @readybin.set_ready(player_data.xlink.audio_file, replay_gain, GtkUI[GtkIDs::MM_PLAYER_LEVELBEFORERG].active?)

            Trace.gst("inited "+build_info_string(player_data, replay_gain, gain_src).brown)
        end
    end

    # Start the track to be played by swaping the ready and play bins
    def play_track(player_data)
        # Swap ready bin and play bin so play bin becomes the next ready bin and
        # the ready bin becomes the actual player
        @playbin, @readybin = @readybin, @playbin

        @playbin.start_track

        # Debug info
#         info = "#{player_data.xlink.audio_file} [#{player_data.xlink.tags.nil? ? player_data.xlink.track.rtrack : 'dropped'}, #{@playbin.get_replay_gain}]"
        Trace.gst("started "+build_info_string(player_data, @playbin.get_replay_gain).cyan)

        # Delayed UI operations start now
        @tip_pix = nil

        # Update the slider to the new track length
        @total_time = @playbin.duration.to_f
        @slider.set_range(0.0, @total_time)
        @total_time = @total_time.to_i

        update_hscale

        player_data.owner.started_playing(player_data)

        GtkUI[GtkIDs::PLAYER_LABEL_TITLE].label = player_data.xlink.html_track_title_no_track_num(false, " ")
        GtkUI[GtkIDs::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PAUSE
        GtkUI[GtkIDs::TTPM_ITEM_PLAY].sensitive = false
        GtkUI[GtkIDs::TTPM_ITEM_PAUSE].sensitive = true
        GtkUI[GtkIDs::TTPM_ITEM_STOP].sensitive = true
        if Cfg.notifications
            file_name = player_data.xlink.cover_file_name
            system("notify-send -t #{(Cfg.notif_duration*1000).to_s} -i #{file_name} 'CDsDB now playing' \"#{player_data.xlink.html_track_title(true)}\"")
        end
    end

    # Fetch the ready bin with the next track if any
    def prepare_next_track
        @queue.compact! # Remove nil entries
        if @queue[0]
            @queue[0].owner.prefetch_tracks(@queue, PREFETCH_SIZE)
            set_ready(@queue[1]) if @queue[1]
        end
    end

    # Handle messages from the window buttons
    def new_track(msg)
        case msg
            when :start
                @queue[0] = @mc.get_track(nil, :start)
            when :next
                # We know @queue[1] is valid because :next is not sent if there's nothing next
                @queue[0].owner.notify_played(@queue[0],  @queue[1].owner != @queue[0].owner ? :finish : :next)
                @queue.shift
            when :prev
                @queue[0] = @queue[0].owner.get_track(@queue[0], :prev)
                @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
        end

        # queue[0] may be nil only if play button is pressed while there's nothing to play
        if @queue[0]
            set_ready(@queue[0])
            play_track(@queue[0])
        end

        prepare_next_track
    end



    ###########################################################################
    # Queue fetching/unfetching
    ###########################################################################

    # Called by mc if any change made in the provider track list
    # or if player source has been switched
    # Second part of test makes sure that we don't refetch from a provider that is
    # not the current provider as selected in the source menu
    def refetch(track_provider)
        if @queue[0] && @mc.track_provider == track_provider
            Trace.ppq("player refetched by #{track_provider.class.name}".red)
            @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
            track_provider.prefetch_tracks(@queue, PREFETCH_SIZE)
            @queue[1] ? set_ready(@queue[1]) : @readybin.stop
            debug_queue if Cfg.trace_gstqueue
        end
    end

    # Called by mc if we have to remove any pending tracks from the queue
    # Play list uses it, when the current playing list is deselected (another one is selected)
    # Also called by mc when source changed to remove the tracks from previous provider
    def unfetch(track_provider)
        if @queue[0] && @queue[1] && @queue[1].owner == track_provider
            Trace.ppq("player unfetched by #{track_provider.class.name}".red)
            @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
            debug_queue if Cfg.trace_gstqueue
        end
    end


    ###########################################################################
    # GStreamerPlayer messages implementation
    ###########################################################################

    def gstplayer_eos
        start = Time.now.to_f
        @queue[1] ? play_track(@queue[1]) : reset_player(true)
        Trace.gst("elapsed: #{"%8.6f" % [Time.now.to_f-start]}")

        # If next provider is different from current, notify current provider it has finished
        @queue[0].owner.notify_played(@queue[0], @queue[1].nil? || @queue[1].owner != @queue[0].owner ? :finish : :next)
        @mc.notify_played(@queue[0].xlink)
        @queue.shift # Remove first entry, no more needed

        prepare_next_track
    end

    def gstplayer_timer
        update_hscale
        return 1 # Gtk timer is stopped if 0 is returned
    end

    def gstplayer_level(msg_struct)
        GStreamer::Player::CHANNELS.each do |channel|
            rms  = msg_struct.get_value("rms").value[channel]
            peak = msg_struct.get_value("decay").value[channel]

            rms = rms > MIN_LEVEL ? (METER_WIDTH*rms / POS_MIN_LEVEL).to_i+METER_WIDTH : 0

            peak = peak > MIN_LEVEL ? (METER_WIDTH*peak / POS_MIN_LEVEL).to_i+METER_WIDTH : 0

            # draw_pixbuf Proto:
            #       draw_pixbuf(gc, copied pixbuf,
            #                   copied pixbuf src_x, copied pixbuf src_y,
            #                   dest (self) dest_x, dest (self) dest_y,
            #                   width, height, dither, x_dither, y_dither)

            unless GtkUI[GtkIDs::MM_PLAYER_LEVEL_SPLIT].active?
                if peak >= METER_WIDTH
                    peak = METER_WIDTH-1
                    @gc.set_rgb_fg_color(OVR_PEAK_COLOR)
                else
                    @gc.set_rgb_fg_color(STD_PEAK_COLOR)
                end

                # Draws the lit part from zero upto the rms level
                @mpix.draw_pixbuf(nil, @bright,
                                  10,  0,
                                  10,  Y_OFFSETS[channel],
                                  rms, 8,
                                  Gdk::RGB::DITHER_NONE, 0, 0)
                # Draws the unlit part from rms level to the end
                @mpix.draw_pixbuf(nil, @dark,
                                  rms+11,            0,
                                  rms+11,            Y_OFFSETS[channel],
                                  METER_WIDTH-rms+1, 8,
                                  Gdk::RGB::DITHER_NONE, 0, 0)

                @mpix.draw_rectangle(@gc, true, peak+9, Y_OFFSETS[channel], 2, 8) if peak > 9
            else
                peak = METER_WIDTH if peak > METER_WIDTH

                if channel == GStreamer::Player::LEFT_CHANNEL
                    @mpix.draw_pixbuf(nil, @bright,
                                      10,   0,
                                      10,   Y_OFFSETS[channel],
                                      peak, 8,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                    # Draws the unlit part from peak & rms level to the end
                    @mpix.draw_pixbuf(nil, @dark,
                                      peak+10,          0,
                                      peak+10,          Y_OFFSETS[channel],
                                      METER_WIDTH-peak, 4,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                    @mpix.draw_pixbuf(nil, @dark,
                                      rms+11,            0,
                                      rms+11,            Y_OFFSETS[channel]+4,
                                      METER_WIDTH-rms+1, 4,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                else
                    @mpix.draw_pixbuf(nil, @bright,
                                      10,   0,
                                      10,   Y_OFFSETS[channel],
                                      peak, 8,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                    # Draws the unlit part from rms & peak level to the end
                    @mpix.draw_pixbuf(nil, @dark,
                                      rms+11,            0,
                                      rms+11,            Y_OFFSETS[channel],
                                      METER_WIDTH-rms+1, 4,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                    @mpix.draw_pixbuf(nil, @dark,
                                      peak+10,          0,
                                      peak+10,          Y_OFFSETS[channel]+4,
                                      METER_WIDTH-peak, 4,
                                      Gdk::RGB::DITHER_NONE, 0, 0)
                end
            end
        end

        # Draw image to screen
        @meter.set(@mpix, nil)
    end


    ###########################################################################
    # Misc methods
    ###########################################################################

    def update_hscale
        return if @seek_handler || !@playbin.active?

        itime = @playbin.play_position
        @slider.value = itime

        show_time(itime)

        @queue[0].owner.timer_notification(itime)
    end

    def show_time(itime)
        if @time_view_mode == ELAPSED
            time_to_digits(format_time(@total_time)+"-"+format_time(itime))
            # To show decreasing time use uncomment this
            # time_to_digits(format_time(@total_time-itime)+"-"+format_time(itime))
        else
            GtkUI[GtkIDs::PLAYER_LABEL_POS].label = "-"+format_time(@total_time-itime)
        end
    end

    def format_time(itime)
        return sprintf("%02d:%02d", itime/60000, (itime % 60000)/1000)
    end

    def show_tooltip(si, tool_tip)
        if @playbin.playing?
            @tip_pix = @queue[0].xlink.large_track_cover if @tip_pix.nil?
            tool_tip.set_icon(@tip_pix)
            text = @queue[0].xlink.html_track_title(true)+"\n\n"+format_time(@slider.value)+" / "+format_time(@total_time)
        else
            text = "\n<b>CDsDB: waiting for tracks to play...</b>\n"
        end
        tool_tip.set_markup(text)
    end

    def debug_queue
        puts(Trace::PPQ+"queue: #{@queue.size} entries:")
        @queue.each { |entry| puts("  #{entry.xlink.track.stitle} <- #{entry.owner.class.name}") }
    end
end
