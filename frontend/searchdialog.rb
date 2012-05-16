
class SearchDialog

    def initialize(mc)
        @mc = mc
        @glade = GTBld::load(UIConsts::SEARCH_DIALOG)
        @glade[UIConsts::SRCH_DLG_BTN_SEARCH].signal_connect(:clicked) { do_search }
        @glade[UIConsts::SRCH_DLG_BTN_SHOW].signal_connect(:clicked)   { do_show }

        # Last column is the table reference (not shown)
        @ls = Gtk::ListStore.new(Integer, String, Integer)

        @tv = @glade[UIConsts::SRCH_DLG_TV]
        @tv.append_column(Gtk::TreeViewColumn.new("Match", Gtk::CellRendererText.new, :text => 0))
        @tv.append_column(Gtk::TreeViewColumn.new("Found in", Gtk::CellRendererText.new, :text => 1))
        @tv.model = @ls
        @tv.selection.mode = Gtk::SELECTION_MULTIPLE

        # May drag tracks to play list or queue
        dragtable = [ ["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700] ]
        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            # Drag/drop is only enabled when viewing track search result set (name or lyrics)
            if @glade[UIConsts::SRCH_DLG_RB_TRACK].active? || @glade[UIConsts::SRCH_DLG_RB_LYRICS].active?
                tracks = "search"
                @tv.selection.selected_each { |model, path, iter| tracks += ":"+iter[2].to_s }
                selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
            end
        }
    end

    def run
        while @glade[UIConsts::SEARCH_DIALOG].run != Gtk::Dialog::RESPONSE_CLOSE do end
        @glade[UIConsts::SEARCH_DIALOG].destroy
    end

    def do_search
        @ls.clear
        txt = ("%"+@glade[UIConsts::SRCH_ENTRY_TEXT].text+"%").to_sql
        if @glade[UIConsts::SRCH_DLG_RB_REC].active?
            sql = "SELECT records.stitle, artists.sname, records.rrecord, records.rrecord FROM records
                   INNER JOIN artists ON artists.rartist = records.rartist
                   WHERE records.stitle LIKE #{txt};"
        end
        if @glade[UIConsts::SRCH_DLG_RB_SEG].active?
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
                iter[1] = row[0]+" by "+row[1]
            else
                iter[1] = row[0]+" from "+row[1]+" by "+row[2]
            end
            iter[2] = row[3]
        end
    end

    def do_show
        return unless @tv.selection.selected_rows
        ref = @ls.get_iter(@tv.selection.selected_rows[0])[2]
        @mc.select_segment(ref) if @glade[UIConsts::SRCH_DLG_RB_SEG].active?
        @mc.select_record(ref) if @glade[UIConsts::SRCH_DLG_RB_REC].active?
        @mc.select_track(ref) if @glade[UIConsts::SRCH_DLG_RB_TRACK].active? || @glade[UIConsts::SRCH_DLG_RB_LYRICS].active?
    end
end
