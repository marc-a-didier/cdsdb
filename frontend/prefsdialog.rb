
module PrefsDialog

    def self.run
        GtkUI.load_window(GtkIDs::PREFS_DIALOG)
        Prefs.restore_window(GtkIDs::PREFS_DIALOG)
        if GtkUI[GtkIDs::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
            Prefs.save_window_objects(GtkIDs::PREFS_DIALOG)
            Cfg.save
        end
        GtkUI[GtkIDs::PREFS_DIALOG].destroy
    end
end
