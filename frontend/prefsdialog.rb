
class PrefsDialog

    def initialize
        GtkUI.load_window(GtkIDs::PREFS_DIALOG)
        PREFS.restore_window_content(GtkUI[GtkIDs::PREFS_DIALOG])
    end

    def run
        if GtkUI[GtkIDs::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
            PREFS.save_window_objects(GtkUI[GtkIDs::PREFS_DIALOG])
            CFG.save
        end
        GtkUI[GtkIDs::PREFS_DIALOG].destroy
    end
end
