
class SearchDialog

    def initialize(mc)
        @mc = mc

        @glade = GTBld::load(UIConsts::SEARCH_DIALOG)

        @dlg = @glade[UIConsts::SEARCH_DIALOG]

        @dlg.signal_connect(:delete_event)   { @dlg.destroy; false }
        @glade[UIConsts::SRCH_DLG_BTN_CLOSE].signal_connect(:clicked) { @dlg.destroy }

        @glade[UIConsts::SRCH_DLG_BTN_SEARCH].signal_connect(:clicked) { do_search }
        @glade[UIConsts::SRCH_DLG_BTN_SHOW].signal_connect(:clicked)   { do_show }

        # Last column is the table reference (not shown)
        @ls = Gtk::ListStore.new(Integer, String, Class)

        title_renderer = Gtk::CellRendererText.new
        title_col = Gtk::TreeViewColumn.new("Found in", title_renderer)
        title_col.set_cell_data_func(title_renderer) { |col, renderer, model, iter| renderer.markup = iter[1] }

        @tv = @glade[UIConsts::SRCH_DLG_TV]
        @tv.append_column(Gtk::TreeViewColumn.new("Match", Gtk::CellRendererText.new, :text => 0))
        @tv.append_column(title_col)
        @tv.model = @ls
        @tv.selection.mode = Gtk::SELECTION_MULTIPLE

        # May drag tracks to play list or queue
        dragtable = [ ["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700] ]
        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            # Drag/drop is only enabled when viewing track search result set (name or lyrics)
            if @glade[UIConsts::SRCH_DLG_RB_TRACK].active? || @glade[UIConsts::SRCH_DLG_RB_LYRICS].active?
                selection_data.set(Gdk::Selection::TYPE_STRING, "search:message:get_search_selection")
            end
        }
    end

    def get_selection
        stores = []
        @tv.selection.selected_each { |model, path, iter| stores << iter[2] }
        return stores
    end

    def search_record?
        return @glade[UIConsts::SRCH_DLG_RB_REC].active?
    end

    def search_segment?
        @glade[UIConsts::SRCH_DLG_RB_SEG].active?
    end

    def search_track?
        return @glade[UIConsts::SRCH_DLG_RB_TRACK].active? || @glade[UIConsts::SRCH_DLG_RB_LYRICS].active?
    end

    def do_search
        @ls.clear
        txt = ("%"+@glade[UIConsts::SRCH_ENTRY_TEXT].text+"%").to_sql
        if search_record?
            sql = "SELECT records.stitle, artists.sname, records.rrecord, records.rrecord FROM records
                   INNER JOIN artists ON artists.rartist = records.rartist
                   WHERE records.stitle LIKE #{txt};"
        end
        if search_segment?
            sql = "SELECT segments.stitle, records.stitle, artists.sname, segments.rsegment FROM segments
                   INNER JOIN records ON records.rrecord = segments.rrecord
                   INNER JOIN artists ON artists.rartist = segments.rartist
                   WHERE segments.stitle LIKE #{txt};"
        end
        if @glade[UIConsts::SRCH_DLG_RB_TRACK].active?
            sql = "SELECT tracks.stitle, records.stitle, artists.sname, tracks.rtrack FROM tracks
                   INNER JOIN records ON records.rrecord = tracks.rrecord
                   INNER JOIN segments ON segments.rsegment = tracks.rsegment
                   INNER JOIN artists ON artists.rartist = segments.rartist
                   WHERE tracks.stitle LIKE #{txt};"
        end
        if @glade[UIConsts::SRCH_DLG_RB_LYRICS].active?
            sql = "SELECT tracks.stitle, records.stitle, artists.sname, tracks.rtrack FROM tracks
                   INNER JOIN records ON records.rrecord = tracks.rrecord
                   INNER JOIN segments ON segments.rsegment = tracks.rsegment
                   INNER JOIN artists ON artists.rartist = segments.rartist
                   WHERE tracks.mnotes LIKE #{txt};"
        end

        i = 0
        DBIntf::connection.execute(sql) do |row|
            i += 1
            iter = @ls.append
            iter[0] = i
            if @glade[UIConsts::SRCH_DLG_RB_REC].active?
                iter[1] = row[0].to_html_bold+" by "+row[1].to_html_italic
            else
                iter[1] = row[0].to_html_bold+" from "+row[1].to_html_italic+" by "+row[2].to_html_italic
            end
            iter[2] = UILink.new.load_track(row[3]) if search_track?
            iter[2] = UILink.new.load_segment(row[3]) if search_segment?
            iter[2] = UILink.new.load_record(row[3]) if search_record?
        end
    end

    def do_show
        return unless @tv.selection.count_selected_rows > 0
        uilink = @ls.get_iter(@tv.selection.selected_rows[0])[2]
        @mc.select_segment(uilink) if search_segment?
        @mc.select_record(uilink) if search_record?
        @mc.select_track(uilink) if search_track?
    end

    def run
        @dlg.show
        return self
#         while @glade[UIConsts::SEARCH_DIALOG].run != Gtk::Dialog::RESPONSE_CLOSE do end
#         @glade[UIConsts::SEARCH_DIALOG].destroy
    end
end
