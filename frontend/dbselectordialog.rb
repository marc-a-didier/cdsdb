
module Dialogs

    class DBSelector

        def initialize(dest_field)
            @dbs = DBClasses.class_from_symbol(dest_field).new

            GtkUI.load_window(GtkIDs::DBSEL_DIALOG)
            GtkUI[GtkIDs::DBSEL_TBBTN_ADD].signal_connect(:clicked)    { do_op_add }
            GtkUI[GtkIDs::DBSEL_TBBTN_EDIT].signal_connect(:clicked)   { do_op_modify }
            GtkUI[GtkIDs::DBSEL_TBBTN_DELETE].signal_connect(:clicked) { do_op_delete }

            @tv = GtkUI[GtkIDs::DBSEL_TV]

            renderer = Gtk::CellRendererText.new
            renderer.editable = true
            renderer.signal_connect(:edited) { |widget, path, new_text| on_tv_edited(widget, path, new_text) }

            @tv.append_column(Gtk::TreeViewColumn.new("ID", Gtk::CellRendererText.new, :text => 0))
            @tv.append_column(Gtk::TreeViewColumn.new("Name/Title", renderer, :text => 1))
            2.times { |i| @tv.columns[i].resizable = true }

            @tv.model = Gtk::ListStore.new(Integer, String)
        end

        def on_tv_edited(widget, path, new_text)
            return if @tv.selection.selected[1] == new_text

            @dbs[0], @dbs[1] = @tv.selection.selected[1], new_text
            @dbs.sql_update

            @tv.selection.selected[1] = new_text

            # Text changed so the tree view resort the list -> reposition on its new place
            @tv.model.each do |model, path, iter|
                if iter[0] == @dbs[0]
                    @tv.set_cursor(iter.path, nil, false)
                    break
                end
            end
        end

        def do_op_add
            @dbs[0], @dbs[1] = @dbs.get_last_id+1, 'New entry'
            @dbs.sql_add

            iter = @tv.model.append
            iter[0], iter[1] = @dbs[0], @dbs[1]
            @tv.set_cursor(iter.path, @tv.columns[1], true)
        end

        def do_op_modify
            return if @tv.selection.selected.nil?
            @tv.set_cursor(@tv.selection.selected.path, @tv.columns[1], true)
        end

        def do_op_delete
            iter = @tv.selection.selected
            return if iter.nil?

            @dbs[0] = iter[0]
            count = @dbs.count_references(@dbs.primary_key == "rorigin" ? "artists" : "records")
            if count > 0
                GtkUtils.show_message("Entry is referenced #{count} time(s) in related tables", Gtk::MessageDialog::ERROR)
            else
                @dbs.sql_del
                @tv.model.remove(iter)
                GtkUtils.show_message("Entry removed", Gtk::MessageDialog::INFO)
            end
        end

        def run
            @dbs.select_all do
                iter = @tv.model.append
                iter[0], iter[1] = @dbs[0], @dbs[1]
            end
            # Always set the sort column AFTER feeding the tree view, it's MUCH faster!
            @tv.model.set_sort_column_id(1, Gtk::SORT_ASCENDING)

            value = nil
            if GtkUI[GtkIDs::DBSEL_DIALOG].run == Gtk::Dialog::RESPONSE_OK
                iter = @tv.selection.selected
                value = iter[0] unless iter.nil?
            end
            GtkUI[GtkIDs::DBSEL_DIALOG].destroy

            return value
        end
    end
end
