
module Prefs

    #
    # Fills the array 'object_list' of objects of 'object_types' type by recursively scanning the
    # object 'object'
    #
    def self.child_controls(object, object_types, object_list)
        object_list << object if object_types.include?(object.class)
        object.children.each { |child| child_controls(child, object_types, object_list) } if object.respond_to?(:children)
        return object_list
    end

    #
    # Windows size & positionning related funcs
    #
    #

    def self.restore_window(gtk_id)
        return if Cfg.windows[gtk_id].nil?
        Cfg.windows[gtk_id].each do |obj, msg|
            msg.each { |method, params| GtkUI[obj].send(method.to_sym, *params) }
        end
    end


    def self.save_window(gtk_id)
        window = GtkUI[gtk_id]

        Cfg.windows[window.builder_name] = { window.builder_name => { "move" => window.position, "resize" => window.size } }

        objs = []
        child_controls(window, [Gtk::HPaned, Gtk::VPaned], objs).each { |obj|
            Cfg.windows[window.builder_name][obj.builder_name] = { "position=" => [obj.position] }
        }

        unless window.class == FilterWindow
            objs = []
            child_controls(window, [Gtk::Expander], objs).each { |obj|
                Cfg.windows[window.builder_name][obj.builder_name] = { "expanded=" => [obj.expanded?] }
            }
        end
    end

    def self.save_windows(gtk_ids)
        gtk_ids.each { |gtk_id| save_window(gtk_id) if GtkUI[gtk_id].visible? }
    end


    #
    # Windows content related funcs (only used by the preferences and export dialog, as far as i remember...)
    #

    def self.save_window_objects(gtk_id)
        window = GtkUI[gtk_id]
        Cfg.windows[window.builder_name] = {}

        object_list = []
        child_controls(window, [Gtk::Entry, Gtk::RadioButton, Gtk::CheckButton, Gtk::FileChooserButton], object_list).each do |obj|
            Cfg.windows[window.builder_name][obj.builder_name] = { "active=" => [obj.active?] } if [Gtk::RadioButton, Gtk::CheckButton].include?(obj.class)
            Cfg.windows[window.builder_name][obj.builder_name] = { "text=" => [obj.text] }  if obj.class == Gtk::Entry
            Cfg.windows[window.builder_name][obj.builder_name] = { "current_folder=" => [obj.current_folder] } if obj.class == Gtk::FileChooserButton
        end
    end


    #
    # Menu config (waiting to find how to discover menus when looping through a window's children
    #

    def self.save_menu_state(menu)
        Cfg.menus[menu.builder_name] = {}
        menu.each { |child|
            Cfg.menus[menu.builder_name][child.builder_name] = { "active=" => [child.active?] } if child.is_a?(Gtk::CheckMenuItem) || child.is_a?(Gtk::RadioMenuItem)
        }
    end

    def self.load_menu_state(menu)
        return if Cfg.menus[menu.builder_name].nil?
        Cfg.menus[menu.builder_name].each do |obj, msg|
            msg.each { |method, params| GtkUI[obj].send(method.to_sym, *params) }
        end
    end


    #
    # Window content save/restore to/from yaml (only used by the filter window)
    #

    FILTER = "filter"

    def self.yaml_from_content(gtk_object)
        yml = { FILTER => {} }

        objs = []
        child_controls(gtk_object, [Gtk::Expander], objs).each { |obj|
            yml[FILTER][obj.builder_name] = { "expanded=" => [obj.expanded?] }
        }

        objs = []
        child_controls(gtk_object, [Gtk::Entry, Gtk::CheckButton, Gtk::SpinButton, Gtk::ComboBox, Gtk::TreeView], objs).each do |obj|
            if obj.class == Gtk::TreeView
                items = ""
                obj.model.each { |model, path, iter| items << (iter[0] ? "1" : "0") }
                yml[FILTER][obj.builder_name] = { "items" => [items] }
                next
            end
            yml[FILTER][obj.builder_name] = { "active=" => [obj.active?] } if obj.class == Gtk::CheckButton
            yml[FILTER][obj.builder_name] = { "active=" => [obj.active] } if obj.class == Gtk::ComboBox
            yml[FILTER][obj.builder_name] = { "text=" => [obj.text] } if obj.class == Gtk::Entry
            yml[FILTER][obj.builder_name] = { "value=" => [obj.value] } if obj.class == Gtk::SpinButton
        end

        return yml.to_yaml.gsub(/\n/, '\n')
    end

    def self.content_from_yaml(yaml_str)
        yml = YAML.load(yaml_str)
        yml[FILTER].each do |obj, msg|
            msg.each do |method, params|
                if method == "items"
                    params[0].bytes.each_with_index { |byte, i| GtkUI[obj].model.get_iter(i.to_s)[0] = byte == 49 } # ascii '1'
                else
                    GtkUI[obj].send(method.to_sym, *params)
                end
            end
        end
    end
end
