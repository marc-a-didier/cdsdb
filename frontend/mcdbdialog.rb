
class MCDBDialog

private

    TITLES      = ["Genre", "Country", "Label", "Medium"] # Columns titles
    TBL_NAMES   = ["genres", "origins", "labels", "medias"] # Table to operate on
    COND_FIELDS = ["records.rgenre", "artists.rorigin", "records.rlabel", "records.rmedia"] # Fields to sort on

public

    GENRES    = 0
    COUNTRIES = 1
    LABELS    = 2
    MEDIA     = 3

    def initialize(sel_table)
        @sel_table = sel_table

        @glade = UIUtils::GladeInstance(UIConsts::GLADE_DIALOGS, UIConsts::MCDB_DIALOG)

        @tv = @glade[UIConsts::MCDB_TV]
        @ls = Gtk::ListStore.new(TrueClass, String, Integer)

        grenderer = Gtk::CellRendererToggle.new
        grenderer.activatable = true
        grenderer.signal_connect(:toggled) do |w, path|
            iter = @ls.get_iter(path)
            iter[0] = !iter[0] if (iter)
        end
        srenderer = Gtk::CellRendererText.new()

        @tv.append_column(Gtk::TreeViewColumn.new("Include", grenderer, :active => 0))
        @tv.append_column(Gtk::TreeViewColumn.new(TITLES[@sel_table], srenderer, :text => 1))
        DBIntf::connection.execute("SELECT * FROM #{TBL_NAMES[@sel_table]};") do |row|
            iter = @ls.append
            iter[0] = true
            iter[1] = row[1]
            iter[2] = row[0]
        end
        @tv.columns[0].clickable = true
        @tv.columns[0].signal_connect(:clicked) { @ls.each { |model, path, iter| iter[0] = !iter[0] } }

        @ls.set_sort_column_id(1, Gtk::SORT_ASCENDING)
        @tv.model = @ls

        FilterPrefs.instance.restore_window_content(@glade, @glade[UIConsts::MCDB_DIALOG], "_"+TBL_NAMES[@sel_table])
    end

    def generate_where_clause
        wc = ""
        total = selected = 0
        @ls.each { |model, path, iter| total += 1; selected += 1 if iter[0] == true }
        if selected > 0 && selected != total
            wc += " AND ("
            cond = ""
            if selected <= total/2
                @ls.each { |model, path, iter| cond += " OR  #{COND_FIELDS[@sel_table]} = #{iter[2]}" if iter[0] == true }
            else
                @ls.each { |model, path, iter| cond += " AND #{COND_FIELDS[@sel_table]} <> #{iter[2]}" if iter[0] == false }
            end
            cond = cond[4..-1]
            wc += cond+")"
        end
        return wc
    end

    def run
        wc = generate_where_clause
        @glade[UIConsts::MCDB_DIALOG].run() do |response|
            if response == Gtk::Dialog::RESPONSE_OK
                wc = generate_where_clause
            elsif response == -20 # Clear
                @ls.each { |model, path, iter| iter[0] = true }
                wc = ""
            end
        end
        FilterPrefs.instance.save_window_objects(@glade[UIConsts::MCDB_DIALOG], "_"+TBL_NAMES[@sel_table])
        @glade[UIConsts::MCDB_DIALOG].destroy()

        return wc
    end
end
