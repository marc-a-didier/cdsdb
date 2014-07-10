
#
# Simple base class that implements the basic mechanisms for windows that are never destroyed
# (play list, play queue, player, charts, tasks, memos)
#

class TopWindow

    attr_reader :mc

    def initialize(mc, window_id)
        @mc = mc
        @window_id = window_id

        window.signal_connect(:show) { PREFS.load_window(self) }
        if window_id != UIConsts::MAIN_WINDOW
            window.signal_connect(:delete_event) { @mc.notify_closed(self); @mc.reset_filter_receiver; true }
        end
    end

    def window
        return @mc.glade[@window_id]
    end

    def show
        window.show
    end

    def hide
        PREFS.save_window(self)
        window.hide
    end

end
