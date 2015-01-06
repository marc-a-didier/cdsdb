
#
# Simple base class that implements the basic mechanisms for windows that are never destroyed
# (play list, play queue, player, charts, tasks, memos)
#

class TopWindow

    attr_reader :mc

    def initialize(mc, gtk_id)
        @mc = mc
        @gtk_id = gtk_id

        window.signal_connect(:show) { PREFS.load_window(self) }
        if gtk_id != GtkIDs::MAIN_WINDOW
            window.signal_connect(:delete_event) do
                @mc.notify_closed(self)
                @mc.reset_filter_receiver
                true
            end
        end
    end

    def window
        return GtkUI[@gtk_id]
    end

    def show
        window.show
    end

    def hide
        PREFS.save_window(self)
        window.hide
    end

end
