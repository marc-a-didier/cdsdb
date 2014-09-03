
class PrefsDialog

    def initialize
        @glade = GTBld.load(UIConsts::PREFS_DIALOG)
        PREFS.restore_window_content(@glade, @glade[UIConsts::PREFS_DIALOG])
    end

    def run
        if @glade[UIConsts::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
            PREFS.save_window_objects(@glade[UIConsts::PREFS_DIALOG])
            CFG.save
        end
        @glade[UIConsts::PREFS_DIALOG].destroy
    end
end
