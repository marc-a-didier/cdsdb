
module Dialogs

    class Search

        def initialize(mc)
            @mc = mc

            GtkUI.load_window(GtkIDs::SEARCH_DIALOG)

            GtkUI[GtkIDs::SEARCH_DIALOG].signal_connect(:show) { Prefs.restore_window(GtkIDs::SEARCH_DIALOG) }
            GtkUI[GtkIDs::SEARCH_DIALOG].signal_connect(:delete_event) do
                Prefs.save_window(GtkIDs::SEARCH_DIALOG)
                GtkUI[GtkIDs::SEARCH_DIALOG].destroy
                false
            end
            GtkUI[GtkIDs::SRCH_DLG_BTN_CLOSE].signal_connect(:clicked) do
                Prefs.save_window(GtkIDs::SEARCH_DIALOG)
                GtkUI[GtkIDs::SEARCH_DIALOG].destroy
            end

            GtkUI[GtkIDs::SRCH_DLG_BTN_SEARCH].signal_connect(:clicked) { search }
            GtkUI[GtkIDs::SRCH_DLG_BTN_SHOW].signal_connect(:clicked)   { show }

            title_renderer = Gtk::CellRendererText.new
            title_col = Gtk::TreeViewColumn.new('Found in', title_renderer)
            title_col.set_cell_data_func(title_renderer) { |col, renderer, model, iter| renderer.markup = iter[1] }

            @tv = GtkUI[GtkIDs::SRCH_DLG_TV]
            @tv.append_column(Gtk::TreeViewColumn.new('Match', Gtk::CellRendererText.new, :text => 0))
            @tv.append_column(title_col)
            # Last column is the table reference (not shown)
            @tv.model = Gtk::ListStore.new(Integer, String, Class)
            @tv.selection.mode = Gtk::SELECTION_MULTIPLE

            # May drag tracks to play list or queue
            dragtable = [ ['browser-selection', Gtk::Drag::TargetFlags::SAME_APP, 700] ]
            @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK,
                                        [['browser-selection', Gtk::Drag::TargetFlags::SAME_APP, 700]],
                                        Gdk::DragContext::ACTION_COPY)
            @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
                # Drag/drop is only enabled when viewing track search result set (name or lyrics)
                if GtkUI[GtkIDs::SRCH_DLG_RB_TRACK].active? || GtkUI[GtkIDs::SRCH_DLG_RB_LYRICS].active?
                    selection_data.set(Gdk::Selection::TYPE_STRING, 'search:message:get_search_selection')
                end
            }

            @tv.set_has_tooltip(true)
            @tv.signal_connect(:query_tooltip) do |widget, x, y, is_kbd, tool_tip|
                widget.show_tool_tip(widget, x, y, is_kbd, tool_tip, 2) if search_track?
            end
        end

        def get_selection
            return @tv.selected_map { |iter| iter[2] }
        end

        def search_record?
            return GtkUI[GtkIDs::SRCH_DLG_RB_REC].active?
        end

        def search_segment?
            GtkUI[GtkIDs::SRCH_DLG_RB_SEG].active?
        end

        def search_track?
            return GtkUI[GtkIDs::SRCH_DLG_RB_TRACK].active? || GtkUI[GtkIDs::SRCH_DLG_RB_LYRICS].active?
        end

        def search
            @tv.model.clear
            txt = ('%'+GtkUI[GtkIDs::SRCH_ENTRY_TEXT].text+'%').to_sql
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
            if GtkUI[GtkIDs::SRCH_DLG_RB_TRACK].active?
                sql = "SELECT tracks.stitle, records.stitle, artists.sname, tracks.rtrack FROM tracks
                    INNER JOIN records ON records.rrecord = tracks.rrecord
                    INNER JOIN segments ON segments.rsegment = tracks.rsegment
                    INNER JOIN artists ON artists.rartist = segments.rartist
                    WHERE tracks.stitle LIKE #{txt};"
            end
            if GtkUI[GtkIDs::SRCH_DLG_RB_LYRICS].active?
                sql = "SELECT tracks.stitle, records.stitle, artists.sname, tracks.rtrack FROM tracks
                    INNER JOIN records ON records.rrecord = tracks.rrecord
                    INNER JOIN segments ON segments.rsegment = tracks.rsegment
                    INNER JOIN artists ON artists.rartist = segments.rartist
                    WHERE tracks.mnotes LIKE #{txt};"
            end

            i = 0
            DBIntf.execute(sql) do |row|
                i += 1
                iter = @tv.model.append
                iter[0] = i
                if GtkUI[GtkIDs::SRCH_DLG_RB_REC].active?
                    iter[1] = row[0].to_html_bold+' by '+row[1].to_html_italic
                else
                    iter[1] = row[0].to_html_bold+' from '+row[1].to_html_italic+' by '+row[2].to_html_italic
                end
                iter[2] = XIntf::Link.new.set_track_ref(row[3]) if search_track?
                iter[2] = XIntf::Link.new.set_segment_ref(row[3]) if search_segment?
                iter[2] = XIntf::Link.new.set_record_ref(row[3]) if search_record?
            end
        end

        def show
            return unless @tv.selection.count_selected_rows > 0
            xlink = @tv.model.get_iter(@tv.selection.selected_rows[0])[2]
            @mc.select_segment(xlink) if search_segment?
            @mc.select_record(xlink) if search_record?
            @mc.select_track(xlink) if search_track?
        end

        def run
            GtkUI[GtkIDs::SEARCH_DIALOG].show
            return self
        end
    end
end
