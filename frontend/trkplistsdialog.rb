
class TrkPListsDialog

    COL_PLIST = 0
    COL_ENTRY = 1
    COL_REF   = 2

    def initialize(mc, rtrack)
        GtkUI.load_window(GtkIDs::TRK_PLISTS_DIALOG)

        tv = GtkUI[GtkIDs::TRK_PLISTS_TV]

        GtkUI[GtkIDs::TRK_PLISTS_BTN_SHOW].signal_connect(:clicked) {
            if tv.selection.selected
                GtkUI[GtkIDs::MM_WIN_PLAYLISTS].send(:activate) unless mc.plists.window.visible?
                mc.plists.position_browser(tv.selection.selected[COL_REF])
            end
        }

        srenderer = Gtk::CellRendererText.new()

        # Columns: Play list, Order, PL track ref (hidden)
        tv.model = Gtk::ListStore.new(String, Integer, Integer)

        tv.append_column(Gtk::TreeViewColumn.new("Play list", srenderer, :text => COL_PLIST))
        tv.append_column(Gtk::TreeViewColumn.new("Entry", srenderer, :text => COL_ENTRY))

        sql = %Q{SELECT plists.sname, pltracks.iorder, pltracks.rpltrack, plists.rplist FROM pltracks
                 INNER JOIN plists ON plists.rplist = pltracks.rplist
                 WHERE pltracks.rtrack=#{rtrack};}
        DBIntf.execute(sql) { |row|
            iter = tv.model.append
            row[1] = DBIntf.get_first_value("SELECT COUNT(rpltrack)+1 FROM pltracks WHERE rplist=#{row[3]} AND iorder<#{row[1]};")
            row.each_with_index { |val, i| iter[i] = val if i < 3 }
        }
    end

    def run
        GtkUI[GtkIDs::TRK_PLISTS_DIALOG].run
        GtkUI[GtkIDs::TRK_PLISTS_DIALOG].destroy
    end
end
