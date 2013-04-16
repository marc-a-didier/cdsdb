

#
# UI handlers designed to be inclued in dbclassintf subclasses (the @dbs struct is mandatory)
#
#
module BaseUI

    # Order in which methods are added to @@handlers
    INT_HDL   = 0
    LKUP_HDL  = 1
    TIME_HDL  = 2
    UDT_HDL   = 3
    NDT_HDL   = 4
    CB_HDL    = 5
    CMB_HDL   = 6
    TV_HDL    = 7
    STR_HDL   = 8
    TXT_HDL   = 9

    FLD_CTRL = 0
    FLD_PROC = 1

    TO_WIDGET   = true
    FROM_WIDGET = false

    TYPES_MAP = {"entry_"      => INT_HDL, "lkentry_" => LKUP_HDL, "timeentry_" => TIME_HDL, "dateentry_" => UDT_HDL,
                 "ndateentry_" => NDT_HDL, "cb_"      => CB_HDL,   "cmb_"       => CMB_HDL,  "tv_"        => TV_HDL,
                 "sentry_"     => STR_HDL, "txtview_" => TXT_HDL }


    #
    # Handlers is an array of proc to do the appropriate job on each type of control that
    # is used in the UI.
    #
    # Each UI (tabs from the main window and editors) is automatically filled and read from
    # using the handler associated to the control which is itself associated to a dbs field.
    #

    @@handlers = []

    def init_handlers
Trace.log.debug("in init_handlers")
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_s : dbs[field] = control.text.to_i
        }
        @@handlers << Proc.new { |control, dbs, field, is_to| # Lookup fields are automotically set when edited so there's no 'from'
            control.text = DBUtils::name_from_id(dbs[field], field[1..-1]) if is_to
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_ms_length : dbs[field] = control.text.to_ms_length
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_std_date : dbs[field] = control.text.to_date_from_utc
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_std_date("Never") : dbs[field] = control.text.to_date_from_utc
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.active = dbs[field] > 0 : dbs[field] = control.active? ? 1 : 0
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.active = dbs[field] : dbs[field] = control.active
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            if is_to
                UIConsts::TAGS.each_index { |i| control.model.get_iter(i.to_s)[0] = dbs[field] & (1 << i) != 0 }
            else
                dbs[field] = 0
                UIConsts::TAGS.each_index { |i| dbs[field] |= (1 << i) if control.model.get_iter(i.to_s)[0] }
            end
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field] : dbs[field] = control.text
        }
        @@handlers << Proc.new { |control, dbs, field, is_to|
            is_to ? control.buffer.text = dbs[field].to_memo : dbs[field] = control.buffer.text.to_dbstring
        }
    end

    def init_baseui(prefix)
Trace.log.debug("in init_baseui: prefix=#{prefix}")
        @controls = {}

        init_handlers if @@handlers.size == 0

        @dbs.members.each { |member|
            TYPES_MAP.each { |ui_type, handler_type|
                if @glade[prefix+ui_type+member.to_s]
                    @controls[member.to_s] = [@glade[prefix+ui_type+member.to_s], @@handlers[handler_type]]
                    break;
                end
            }
        }
    end

    def field_to_widget(field)
        @controls[field][FLD_PROC].call(@controls[field][FLD_CTRL], @dbs, field, TO_WIDGET)
    end

    def struct_to_widgets
        @controls.each_key { |key| field_to_widget(key) }
    end

    def widget_to_field(field)
        @controls[field][FLD_PROC].call(@controls[field][FLD_CTRL], @dbs, field, FROM_WIDGET)
    end

    def widgets_to_struct
        @controls.each_key { |key| widget_to_field(key) }
    end

    def to_widgets
        struct_to_widgets
        return self
    end

    def from_widgets
        widgets_to_struct
        return self
    end

    def select_dialog(dbfield)
        value = DBSelectorDialog.new.run(dbfield[1..-1])
        unless value == -1
            @dbs[dbfield] = value
#             self.sql_update.field_to_widget(dbfield)
            self.field_to_widget(dbfield)
        end
    end

end


#
# Overrides from_widgets in order to save only the text view entry of the main window tabs.
# Must be included AFTER BaseUI
#
module MainTabsUI

    def from_widgets
        widget_to_field("mnotes")
        return self
    end

    def to_infos_widget(widget)
        widget.text = build_infos_string
        return self
    end

end
