
class PrefsDialog

    def initialize
        GtkUI.load_window(GtkIDs::PREFS_DIALOG)
        Prefs.restore_window(GtkIDs::PREFS_DIALOG)
    end

    def run
        if GtkUI[GtkIDs::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
            Prefs.save_window_objects(GtkIDs::PREFS_DIALOG)
            CFG.save
        end
        GtkUI[GtkIDs::PREFS_DIALOG].destroy
    end
end
