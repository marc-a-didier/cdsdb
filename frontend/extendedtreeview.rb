
class Gtk::TreeView

    attr_accessor :mc

#     def initialize(mc)
#         super()
#         @mc = mc
#     end

    def finalize_setup
        set_ref_column_visibility(GtkUI[GtkIDs::MM_VIEW_DBREFS].active?)
        return self
    end

    def load_entries
        raise "load_entries not overriden!"
    end

    def clear
        model.clear
    end

    def find_ref(ref, column = 0)
        model.each { |model, path, iter| return iter if iter[column] == ref }
        return nil
    end

    def position_to(ref)
        iter = find_ref(ref)
        set_cursor(iter.path, nil, false) if iter
        return iter
    end

    def row_visible?(ref)
        iter = find_ref(ref)
        if iter
            return true if iter.parent.nil? || row_expanded?(iter.parent.path)
        end
        return false
    end

    def change_sort_order(col_id)
        columns[col_id].sort_order == Gtk::SORT_ASCENDING ?
            columns[col_id].sort_order = Gtk::SORT_DESCENDING :
            columns[col_id].sort_order = Gtk::SORT_ASCENDING

        # Reposition the cursor on the same entry if selected and a block to update the view is given
        ref = selection.selected ? selection.selected[0] : -1
        #yield if block_given?
        load_entries
        position_to(ref) if ref != -1
    end

    def set_ref_column_visibility(is_visible)
        columns[0].visible = is_visible
    end

    # Delete all children of iter EXCEPT the first one (gtk treeview requirement)
    # Return the first child iter so it can be safely removed later
    def remove_children_but_first(iter)
        if fchild = iter.first_child
            itr = iter.first_child
            model.remove(itr) while itr.next! # while is called BEFORE remove
        end
        return fchild
    end

    def remove_children(iter)
        model.remove(iter.first_child) while iter.first_child
    end

    def show_popup(widget, event, menu_name)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            # No popup if no selection in the tree view except in admin mode
            return if selection.selected.nil? && !Cfg.admin?
            @mc.update_tags_menu(self, GtkUI[GtkIDs::REC_POPUP_TAGS]) if self.instance_of?(RecordsBrowser)
            GtkUI[menu_name].popup(nil, nil, event.button, event.time)
        end
    end


end
