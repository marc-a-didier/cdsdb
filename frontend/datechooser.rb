
class DateChooser

    include GtkIDs

    def initialize
        GtkUI.load_window(DLG_DATE_CHOOSER)

        GtkUI[DTDLG_BTN_FROMDATE].signal_connect(:clicked) { set_date(GtkUI[DTDLG_ENTRY_FROMDATE]) }
        GtkUI[DTDLG_BTN_TODATE].signal_connect(:clicked)   { set_date(GtkUI[DTDLG_ENTRY_TODATE])   }

        @dates = nil
   end

    def set_date(control)
        GtkUI.load_window(DLG_DATE_SELECTOR)
        GtkUI[DATED_CALENDAR].signal_connect(:day_selected_double_click) { GtkUI[DATED_BTN_OK].send(:clicked) }
        if GtkUI[DLG_DATE_SELECTOR].run == Gtk::Dialog::RESPONSE_OK
            dt = GtkUI[DATED_CALENDAR].date
            control.text = dt[0].to_s+"-"+dt[1].to_s+"-"+dt[2].to_s
        end
        GtkUI[DLG_DATE_SELECTOR].destroy
    end

    def run
        GtkUI[DLG_DATE_CHOOSER].run { |response|
            if response == Gtk::Dialog::RESPONSE_OK
                @dates = [GtkUI[DTDLG_ENTRY_FROMDATE].text.to_date, GtkUI[DTDLG_ENTRY_TODATE].text.to_date]

                # Switch dates if only until date is filled
                (@dates[0], @dates[1] = @dates[1], @dates[0]) if @dates[0] == 0

                # Do nothing if no dates given or no from date
                if @dates[0] != 0
                    # If no until date, set it to the same day
                    @dates[1] = @dates[0] if @dates[1] == 0
                    # Set until date to next day at 0:00
                    @dates[1] += 60*60*24
                end
                @dates = nil if @dates[0] == 0
            end
        }
        return self
    end

    def close
        GtkUI[DLG_DATE_CHOOSER].destroy
    end

    def dates
        return @dates
    end
end
