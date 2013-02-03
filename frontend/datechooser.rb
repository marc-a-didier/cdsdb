
class DateChooser

    include UIConsts

    def initialize
        @glade = GTBld::load(DLG_DATE_CHOOSER)

        @dlg = @glade[DLG_DATE_CHOOSER]

        @glade[DTDLG_BTN_FROMDATE].signal_connect(:clicked) { set_date(@glade[DTDLG_ENTRY_FROMDATE]) }
        @glade[DTDLG_BTN_TODATE].signal_connect(:clicked)   { set_date(@glade[DTDLG_ENTRY_TODATE])   }

        @dates = nil
   end

    def set_date(control)
        dlg_glade = GTBld.load(DLG_DATE_SELECTOR)
        dlg_glade[DATED_CALENDAR].signal_connect(:day_selected_double_click) { dlg_glade[DATED_BTN_OK].send(:clicked) }
        if dlg_glade[DLG_DATE_SELECTOR].run == Gtk::Dialog::RESPONSE_OK
            dt = dlg_glade[DATED_CALENDAR].date
            control.text = dt[0].to_s+"-"+dt[1].to_s+"-"+dt[2].to_s
        end
        dlg_glade[DLG_DATE_SELECTOR].destroy
    end

    def run
        @dlg.run { |response|
            if response == Gtk::Dialog::RESPONSE_OK
                @dates = []
                @dates << @glade[DTDLG_ENTRY_FROMDATE].text.to_date
                @dates << @glade[DTDLG_ENTRY_TODATE].text.to_date
                if @dates[0] == 0 && @dates[1] != 0
                    @dates[0] = @dates[1]
                    @dates[1] = 0
                end
                @dates[1] = @dates[0]+60*60*24 if @dates[0] != 0 # Set for whole day
                @dates = nil if @dates[0] == 0 && @dates[1] == 0
            end
        }
        return self
    end

    def close
        @dlg.destroy
    end

    def dates
        return @dates
    end
end
