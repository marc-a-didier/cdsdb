

#
# Handlers is an array of proc to do the appropriate job on each type of control that
# is used in the UI.
#
# Each UI element is automatically filled and read
# using the handler associated to the control which is itself associated to a dbs field.
#
GTK_HANDLERS = {
    'entry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_s : dbs[field] = control.text.to_i
        },
    'lkentry_' =>
        Proc.new { |control, dbs, field, is_to| # Lookup fields are automotically set when edited so there's no 'from'
            control.text = DBUtils::name_from_id(dbs[field], field[1..-1]) if is_to
        },
    'timeentry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_ms_length : dbs[field] = control.text.to_ms_length
        },
    'dateentry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_std_date : dbs[field] = control.text.to_date_from_utc
        },
    'ndateentry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_std_date('Never') : dbs[field] = control.text.to_date_from_utc
        },
    'cb_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.active = dbs[field] > 0 : dbs[field] = control.active? ? 1 : 0
        },
    'cmb_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.active = dbs[field] : dbs[field] = control.active
        },
    'tv_' =>
        Proc.new { |control, dbs, field, is_to|
            if is_to
                Qualifiers::TAGS.each_index { |i| control.model.get_iter(i.to_s)[0] = dbs[field] & (1 << i) != 0 }
            else
                dbs[field] = 0
                Qualifiers::TAGS.each_index { |i| dbs[field] |= (1 << i) if control.model.get_iter(i.to_s)[0] }
            end
        },
    'sentry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field] : dbs[field] = control.text
        },
    'txtview_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.buffer.text = dbs[field].to_memo : dbs[field] = control.buffer.text.to_dbstring
        },
    'fltentry_' =>
        Proc.new { |control, dbs, field, is_to|
            is_to ? control.text = dbs[field].to_s : dbs[field] = control.text.to_f
        }
}


#
# UI handlers designed to be included in dbclassintf subclasses (the @dbs struct is mandatory)
#
#

module BaseUI

    FLD_CTRL = 0
    FLD_PROC = 1

    TO_WIDGET   = true
    FROM_WIDGET = false


    def init_baseui(prefix)
        @controls = {}

        @dbs.members.each { |member|
            GTK_HANDLERS.each { |ui_type, handler_proc|
                if GtkUI[prefix+ui_type+member.to_s]
                    @controls[member.to_s] = [GtkUI[prefix+ui_type+member.to_s], handler_proc]
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
