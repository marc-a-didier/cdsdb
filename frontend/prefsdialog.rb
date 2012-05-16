
class PrefsDialog

    def initialize
        @glade = GTBld.load(UIConsts::PREFS_DIALOG)
        Prefs::instance.restore_window_content(@glade, @glade[UIConsts::PREFS_DIALOG])
    end

    def run
        if @glade[UIConsts::PREFS_DIALOG].run == Gtk::Dialog::RESPONSE_OK
            Prefs::instance.save_window_objects(@glade[UIConsts::PREFS_DIALOG])
            Cfg::instance.load
        end
        @glade[UIConsts::PREFS_DIALOG].destroy
    end
end
