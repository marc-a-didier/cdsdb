
class RecentTracksDialog

    COL_ENTRY = 0
    COL_PIX   = 1
    COL_TITLE = 2
    COL_DATE  = 3
    COL_REF   = 4

    def initialize(mc, view_type)
        @mc = mc

        @glade = GTBld::load(UIConsts::RECENT_TRACKS_DIALOG)

        @dlg = @glade[UIConsts::RECENT_TRACKS_DIALOG]

        @glade[UIConsts::RECTRACKS_BTN_SHOW].signal_connect(:clicked) {
            @mc.select_track(@tv.selection.selected[COL_REF]) if @tv.selection.selected
        }

        @tv = @glade[UIConsts::RECTRACKS_TV]

        srenderer = Gtk::CellRendererText.new()

        # Columns: Entry, cover, title, date, Track ref (hidden)
        @ls = Gtk::ListStore.new(Integer, Gdk::Pixbuf, String, String, Integer)

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
            selection_data.set(Gdk::Selection::TYPE_STRING, ":"+@tv.selection.selected[COL_REF].to_s)
        }

        if view_type == 0
            sql =  "SELECT logtracks.rtrack, logtracks.idateplayed, logtracks.shostname FROM logtracks " \
                   "ORDER BY logtracks.idateplayed DESC LIMIT #{Cfg::instance.max_items};"
        else
            sql =  "SELECT logtracks.rtrack, logtracks.idateplayed, logtracks.shostname FROM logtracks " \
                   "INNER JOIN tracks ON logtracks.rtrack=tracks.rtrack " \
                   "ORDER BY logtracks.idateplayed, tracks.iplayed LIMIT #{Cfg::instance.max_items};"
        end
        track_infos = TrackInfos.new
        i = 0
        DBIntf::connection.execute(sql) do |row|
            i += 1
            iter = @ls.append
            rtrack = row[0].to_i
            track_infos.get_track_infos(rtrack)
            iter[COL_ENTRY] = i
            iter[COL_PIX]  = IconsMgr::instance.get_cover(track_infos.record.rrecord, rtrack, track_infos.record.irecsymlink, 64)
            iter[COL_TITLE] = UIUtils::html_track_title(track_infos, @mc.show_segment_title?)
            iter[COL_DATE] = Time.at(row[1]).strftime("%a %b %d %Y %H:%M:%S")+" @ "+row[2]
            iter[COL_REF] = rtrack
        end

        @tv.model = @ls
    end

    def run
        @dlg.run
        @dlg.destroy
    end
end
