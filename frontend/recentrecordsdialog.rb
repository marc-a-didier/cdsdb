
class RecentRecordsDialog

    VIEW_RECENT = 0
    VIEW_RIPPED = 1

    COL_ENTRY = 0
    COL_PIX   = 1
    COL_TITLE = 2
    COL_DATE  = 3
    COL_REF   = 4

    def initialize(mc, view_type)
        @mc = mc
        @filter = ""

        @glade = GTBld::load(UIConsts::RECENT_RECORDS_DIALOG)

        @dlg = @glade[UIConsts::RECENT_RECORDS_DIALOG]

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        @dlg.add_events( Gdk::Event::FOCUS_CHANGE)
        @dlg.signal_connect(:focus_in_event) { |widget, event| @mc.filter_receiver = self; false }
        @dlg.signal_connect(:delete_event)   { puts "delete received"; @mc.reset_filter_receiver; @dlg.destroy; false }

        # J'aimerais bien piger une fois comment on envoie un delete_event a la fenetre!!!
        #@glade["recrec_btn_close"].signal_connect(:clicked) { @dlg.delete } # @dlg.signal_emit(:delete_event, Gdk::Event.new(Gdk::Event::DESTROY)) }
        @glade[UIConsts::RECREC_BTN_CLOSE].signal_connect(:clicked) { puts "closing"; @mc.reset_filter_receiver; @dlg.destroy }

        @glade[UIConsts::RECREC_BTN_SHOW].signal_connect(:clicked) {
            @mc.select_record(@tv.selection.selected[COL_REF]) if @tv.selection.selected
        }

        @tv = @glade[UIConsts::RECREC_TV]

        srenderer = Gtk::CellRendererText.new()

        # Columns: Entry, cover, title, date, Record ref (hidden)
        @tv.model = Gtk::ListStore.new(Integer, Gdk::Pixbuf, String, String, Integer)

        pix = Gtk::CellRendererPixbuf.new
        pixcol = Gtk::TreeViewColumn.new("Cover")
        pixcol.pack_start(pix, false)
        pixcol.set_cell_data_func(pix) { |column, cell, model, iter| cell.pixbuf = iter[COL_PIX] }

        title_renderer = Gtk::CellRendererText.new
        title_column = Gtk::TreeViewColumn.new("Track", title_renderer)
        title_column.set_cell_data_func(title_renderer) { |col, renderer, model, iter| renderer.markup = iter[COL_TITLE] }

        @tv.append_column(Gtk::TreeViewColumn.new("Entry", srenderer, :text => COL_ENTRY))
        @tv.append_column(pixcol)
        @tv.append_column(title_column)
        @tv.append_column(Gtk::TreeViewColumn.new("Date", srenderer, :text => COL_DATE))

        #@tv.columns[COL_TITLE].resizable = true

        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            tracks = ""
            DBIntf::connection.execute("SELECT rtrack FROM tracks WHERE rrecord=#{@tv.selection.selected[COL_REF]};") { |row| tracks += ":"+row[0].to_s }
            selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
        }

        @view_type = view_type
        exec_sql(@view_type)
    end

    def set_filter(where_clause, must_join_logtracks = false)
        @filter = where_clause
        exec_sql(@view_type);
    end
    
    def exec_sql(view_type)
        if view_type == VIEW_RECENT
            sql =  "SELECT DISTINCT(records.rrecord), records.stitle, artists.sname, records.idateadded, records.irecsymlink FROM tracks " \
                   "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                   "INNER JOIN records ON records.rrecord=segments.rrecord " \
                   "INNER JOIN artists ON artists.rartist=records.rartist "
            sql += "WHERE #{@filter[4..-1]} " unless @filter.empty?
            sql += "ORDER BY records.idateadded DESC LIMIT #{Cfg::instance.max_items};"
        else
            sql = "SELECT DISTINCT(records.rrecord), records.stitle, artists.sname, records.idateripped, records.irecsymlink FROM tracks " \
                  "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                  "INNER JOIN records ON records.rrecord=segments.rrecord " \
                  "INNER JOIN artists ON artists.rartist=records.rartist " \
                  "WHERE records.idateripped<>0 #{@filter}" \
                  "ORDER BY records.idateripped DESC LIMIT #{Cfg::instance.max_items};"
        end

        @tv.model.clear
        i = 0
        DBIntf::connection.execute(sql) do |row|
            i += 1
            iter = @tv.model.append
            iter[COL_ENTRY] = i
            iter[COL_PIX]  = IconsMgr::instance.get_cover(row[0], 0, row[4], 64)
            iter[COL_TITLE] = "<b>"+CGI::escapeHTML(row[1])+"</b>\n"+
                              "by <i>"+CGI::escapeHTML(row[2])+"</i>"
            iter[COL_DATE] = row[3] == 0 ? "Unknown" : Time.at(row[3]).to_s
            iter[COL_REF] = row[0]
        end
    end

    def run
        @dlg.show
    end
end
