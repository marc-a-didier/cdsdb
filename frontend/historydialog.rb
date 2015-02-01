
module Dialogs

    class History

        VIEW_ADDED  = 0
        VIEW_RIPPED = 1
        VIEW_PLAYED = 2
        VIEW_DATES  = 3

        COL_ENTRY = 0
        COL_PIX   = 1
        COL_TITLE = 2
        COL_DATE  = 3
        COL_DATA  = 4

        def initialize(mc, view_type, dates)
            @mc = mc
            @filter = ""
            @dates = dates

            GtkUI.load_window(GtkIDs::DLG_HISTORY)

            dlg = GtkUI[GtkIDs::DLG_HISTORY]

            # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
            dlg.add_events( Gdk::Event::FOCUS_CHANGE)
            dlg.signal_connect(:focus_in_event) { |widget, event| @mc.filter_receiver = self; false }
            dlg.signal_connect(:show)           { Prefs.restore_window(GtkIDs::DLG_HISTORY) }
            dlg.signal_connect(:delete_event)   { notify_and_close; false }

            # J'aimerais bien piger une fois comment on envoie un delete_event a la fenetre!!!
            GtkUI[GtkIDs::HISTORY_BTN_CLOSE].signal_connect(:clicked) { notify_and_close }

            GtkUI[GtkIDs::HISTORY_BTN_SHOW].signal_connect(:clicked) {
                if @view_type == VIEW_PLAYED
                    @mc.select_track(@tv.selection.selected[COL_DATA]) if @tv.selection.selected
                else
                    @mc.select_record(@tv.selection.selected[COL_DATA]) if @tv.selection.selected
                end
            }

            @tv = GtkUI[GtkIDs::HISTORY_TV]

            srenderer = Gtk::CellRendererText.new()

            # Columns: Entry, cover, title, date, XIntf::Link (hidden)
            @tv.model = Gtk::ListStore.new(Integer, Gdk::Pixbuf, String, String, Class)

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

            @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK,
                                         [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]],
                                         Gdk::DragContext::ACTION_COPY)
            @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
                selection_data.set(Gdk::Selection::TYPE_STRING, "history:message:get_history_selection:#{@view_type}")
            }

            @view_type = view_type
            exec_sql(@view_type)
        end

        def present
            GtkUI[GtkIDs::DLG_HISTORY].present
        end

        def notify_and_close
            @mc.reset_filter_receiver
            @mc.history_closed(self)
            Prefs.save_window(GtkIDs::DLG_HISTORY)
            GtkUI[GtkIDs::DLG_HISTORY].destroy
        end

        def get_selection
            links = []
            if @view_type == VIEW_PLAYED || @view_type == VIEW_DATES
                links << @tv.selection.selected[COL_DATA] #.clone
            else
                sql = "SELECT rtrack FROM tracks WHERE rrecord=#{@tv.selection.selected[COL_DATA].record.rrecord};"
                DBIntf.execute(sql) { |row| links << XIntf::Link.new.set_track_ref(row[0]).set_use_of_record_gain }
            end
            return links
        end

        def set_filter(where_clause, must_join_logtracks = false)
            @filter = where_clause
            exec_sql(@view_type)
        end

        def exec_sql(view_type)
            sql = case view_type
                when VIEW_ADDED
                    %Q{SELECT DISTINCT(records.rrecord), records.stitle, artists.sname, records.idateadded, records.irecsymlink FROM tracks
                    INNER JOIN segments ON tracks.rsegment=segments.rsegment
                    INNER JOIN records ON records.rrecord=segments.rrecord
                    INNER JOIN artists ON artists.rartist=records.rartist
                    WHERE records.idateadded<>0 #{@filter}
                    ORDER BY records.idateadded DESC LIMIT #{Cfg.max_items};}
                when VIEW_RIPPED
                    %Q{SELECT DISTINCT(records.rrecord), records.stitle, artists.sname, records.idateripped, records.irecsymlink FROM tracks
                    INNER JOIN segments ON tracks.rsegment=segments.rsegment
                    INNER JOIN records ON records.rrecord=segments.rrecord
                    INNER JOIN artists ON artists.rartist=records.rartist
                    WHERE records.idateripped<>0 #{@filter}
                    ORDER BY records.idateripped DESC LIMIT #{Cfg.max_items};}
                when VIEW_PLAYED
                    # The WHERE clause was added to add a WHERE for the filter if any. Should be changed...
                    %Q{SELECT logtracks.rtrack, logtracks.idateplayed, hostnames.sname, records.rrecord, records.irecsymlink FROM logtracks
                    INNER JOIN hostnames ON hostnames.rhostname=logtracks.rhostname
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                    INNER JOIN segments ON tracks.rsegment=segments.rsegment
                    INNER JOIN records ON records.rrecord=segments.rrecord
                    INNER JOIN artists ON artists.rartist=records.rartist
                    WHERE tracks.iplayed > 0 #{@filter}
                    ORDER BY logtracks.idateplayed DESC LIMIT #{Cfg.max_items};}
                when VIEW_DATES
                    %Q{SELECT logtracks.rtrack, logtracks.idateplayed, hostnames.sname, records.rrecord, records.irecsymlink FROM logtracks
                    INNER JOIN hostnames ON hostnames.rhostname=logtracks.rhostname
                    INNER JOIN tracks ON tracks.rtrack=logtracks.rtrack
                    INNER JOIN segments ON tracks.rsegment=segments.rsegment
                    INNER JOIN records ON records.rrecord=segments.rrecord
                    INNER JOIN artists ON artists.rartist=records.rartist
                    WHERE logtracks.idateplayed >= #{@dates[0]} AND logtracks.idateplayed <= #{@dates[1]}
                    ORDER BY logtracks.idateplayed DESC;}
            end

            @tv.model.clear
            i = 0
            DBIntf.execute(sql) do |row|
                i += 1
                iter = @tv.model.append
                iter[COL_ENTRY] = i
                iter[COL_DATA] = XIntf::Link.new

                if @view_type == VIEW_PLAYED || @view_type == VIEW_DATES
                    iter[COL_DATA].set_track_ref(row[0])
                    iter[COL_PIX]   = iter[COL_DATA].small_track_cover
                    iter[COL_TITLE] = iter[COL_DATA].html_track_title_no_track_num(@mc.show_segment_title?)
                    iter[COL_DATE]  = row[1].to_std_date+" @ "+row[2]
                else
                    iter[COL_DATA].set_record_ref(row[0])
                    iter[COL_PIX]   = iter[COL_DATA].small_record_cover
                    iter[COL_TITLE] = row[1].to_html_bold+"\nby "+row[2].to_html_italic
                    iter[COL_DATE]  = row[3].to_std_date
                end
            end
        end

        def run
            GtkUI[GtkIDs::DLG_HISTORY].show
            return self
        end
    end
end
