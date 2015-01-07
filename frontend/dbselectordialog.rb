
class DBSelectorDialog

    def initialize
        @tbl_name = ""
        @tbl_ref  = ""

        GtkUI.load_window(GtkIDs::DBSEL_DIALOG)
        GtkUI[GtkIDs::DBSEL_TBBTN_ADD].signal_connect(:clicked)    { do_op_add() }
        GtkUI[GtkIDs::DBSEL_TBBTN_EDIT].signal_connect(:clicked)   { do_op_modify() }
        GtkUI[GtkIDs::DBSEL_TBBTN_DELETE].signal_connect(:clicked) { do_op_delete() }

        @tv = GtkUI[GtkIDs::DBSEL_TV]

        renderer = Gtk::CellRendererText.new()
        renderer.editable = true
        renderer.signal_connect(:edited) { |widget, path, new_text| on_tv_edited(widget, path, new_text) }

        @tv.append_column(Gtk::TreeViewColumn.new("ID", Gtk::CellRendererText.new(), :text => 0))
        @tv.append_column(Gtk::TreeViewColumn.new("Name/Title", renderer, :text => 1))
        2.times { |i| @tv.columns[i].resizable = true }

        @tv.model = Gtk::ListStore.new(Integer, String)
        @tv.model.set_sort_column_id(1, Gtk::SORT_ASCENDING)
    end

    def on_tv_edited(widget, path, new_text)
        return if @tv.selection.selected[1] == new_text
        DBUtils::client_sql("UPDATE #{@tbl_name} SET sname=#{new_text.to_sql} WHERE #{@tbl_ref}=#{@tv.selection.selected[0]};")
        @tv.selection.selected[1] = new_text
        ref = @tv.selection.selected[0]
        @tv.model.each { |model, path, iter|
            if iter[0] == ref
                @tv.set_cursor(iter.path, nil, false)
                break
            end
        }
    end

    def do_op_add()
        ref = DBUtils::get_last_id(@tbl_name[0..-2])+1
        DBUtils::client_sql("INSERT INTO #{@tbl_name} VALUES (#{ref}, 'New entry');")
        iter = @tv.model.append()
        iter[0] = ref
        iter[1] = "New entry"
        @tv.set_cursor(iter.path, @tv.columns[1], true)
    end

    def do_op_modify()
        return if @tv.selection.selected.nil?
        @tv.set_cursor(@tv.selection.selected.path, @tv.columns[1], true)
    end

    def do_op_delete()
        iter = @tv.selection().selected()
        return if iter.nil?
        if @tbl_name == "origins"
            count = DBIntf.get_first_value("SELECT COUNT(rartist) FROM artists WHERE #{@tbl_ref}=#{iter[0]}")
        else
            count = DBIntf.get_first_value("SELECT COUNT(rrecord) FROM records WHERE #{@tbl_ref}=#{iter[0]}")
        end
        if count > 0
            GtkUtils.show_message("Error: #{count} reference(s) still in artists or records table", Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM #{@tbl_name} WHERE #{@tbl_ref}=#{iter[0]}")
            @tv.model.remove(iter)
            GtkUtils.show_message("Entry removed", Gtk::MessageDialog::INFO)
        end
    end

    def run(tbl_id)
        @tbl_name = tbl_id+"s"
        @tbl_ref  = "r"+tbl_id
        #DBIntf.execute( "SELECT * FROM #{@tbl_name} WHERE #{@tbl_ref} > 1;" ) do |row|
        DBIntf.execute( "SELECT * FROM #{@tbl_name};" ) do |row|
            iter = @tv.model.append()
            iter[0] = row[0]
            iter[1] = row[1]
        end

        value = -1
        GtkUI[GtkIDs::DBSEL_DIALOG].run() do |response|
            if response == Gtk::Dialog::RESPONSE_OK
                iter = @tv.selection().selected()
                value = iter[0] unless iter.nil?
            end
        end
        GtkUI[GtkIDs::DBSEL_DIALOG].destroy()

        return value
    end
end
