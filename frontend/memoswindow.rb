
class MemosWindow < TopWindow

    def initialize(mc)
        super(mc, GtkIDs::MEMOS_WINDOW)

        # Add a Ctrl+S accelerator that call the main window action saving the memos content
        ag = Gtk::AccelGroup.new
        ag.connect(Gdk::Keyval::GDK_S, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
            GtkUI[GtkIDs::MW_MEMO_SAVE_ACTION].send(:activate)
        }
        window.add_accel_group(ag)
    end

end
