
ExportParams = Struct.new(:src_folder, :dest_folder, :remove_genre, :fat_compat)

class ExportDialog

    def initialize()
        @glade = GTBld::load(UIConsts::EXPORT_DEVICE_DIALOG)
        PREFS.restore_window_content(@glade, @glade[UIConsts::EXPORT_DEVICE_DIALOG])
    end

    def run(exp_params)
        resp = @glade[UIConsts::EXPORT_DEVICE_DIALOG].run
        if resp == Gtk::Dialog::RESPONSE_OK
            PREFS.save_window_objects(@glade[UIConsts::EXPORT_DEVICE_DIALOG])
            exp_params.src_folder   = @glade[UIConsts::EXP_DLG_FC_SOURCE].current_folder+"/"
            exp_params.dest_folder  = @glade[UIConsts::EXP_DLG_FC_DEST].current_folder+"/"
            exp_params.remove_genre = @glade[UIConsts::EXP_DLG_CB_RMGENRE].active?
            exp_params.fat_compat   = @glade[UIConsts::EXP_DLG_CB_FATCOMPAT].active?
        end
        destroy #unless resp == Gtk::Dialog::RESPONSE_OK
        return resp
    end

#     def src
#         return @glade[UIConsts::EXP_DLG_FC_SOURCE].current_folder+"/"
#     end
#
#     def dest
#         return @glade[UIConsts::EXP_DLG_FC_DEST].current_folder+"/"
#     end
#
#     def remove_genre?
#         return @glade[UIConsts::EXP_DLG_CB_RMGENRE].active?
#     end
#
#     def fat_compat?
#         return @glade[UIConsts::EXP_DLG_CB_FATCOMPAT].active?
#     end

    def destroy
        @glade[UIConsts::EXPORT_DEVICE_DIALOG].destroy
    end
end
