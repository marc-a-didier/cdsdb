
class Prefs

    include Singleton

    #
    # Fills the array 'object_list' of objects of 'object_types' type by recursively scanning the
    # object 'object'
    #
    def child_controls(object, object_types, object_list)
        object_list << object if object_types.include?(object.class)
        object.children.each { |child| child_controls(child, object_types, object_list) } if object.respond_to?(:children)
        return object_list
    end

    #
    # Windows size & positionning related funcs
    #
    #

    # Called by windows or dialogs that are not TopWindow descendants.
    def load_main(glade, name)
        return if CFG.windows[name].nil?
        CFG.windows[name].each do |obj, msg|
            msg.each { |method, params| glade[obj].send(method.to_sym, *params) }
        end
    end

    # Called by TopWindow descendants to restore their attributes
    def load_window(top_window)
        return if CFG.windows[top_window.window.builder_name].nil?
        CFG.windows[top_window.window.builder_name].each do |obj, msg|
            msg.each { |method, params| top_window.mc.glade[obj].send(method.to_sym, *params) }
        end
    end

    def save_window(any_window)
        window = any_window.kind_of?(TopWindow) ? any_window.window : any_window

        CFG.windows[window.builder_name] = { window.builder_name => { "move" => window.position, "resize" => window.size } }

        objs = []
        child_controls(window, [Gtk::HPaned, Gtk::VPaned], objs).each { |obj|
            CFG.windows[window.builder_name][obj.builder_name] = { "position=" => [obj.position] }
        }

        unless any_window.class == FilterWindow
            objs = []
            child_controls(window, [Gtk::Expander], objs).each { |obj|
                CFG.windows[window.builder_name][obj.builder_name] = { "expanded=" => [obj.expanded?] }
            }
        end
    end

    def save_windows(win_list)
        win_list.each { |window| save_window(window) if window.window.visible? }
    end


    #
    # Windows content related funcs (only used by the preferences dialog, as far as i remember...)
    #

    def save_window_objects(window)
        CFG.windows[window.builder_name] = {}

        object_list = []
        child_controls(window, [Gtk::Entry, Gtk::RadioButton, Gtk::CheckButton, Gtk::FileChooserButton], object_list).each do |obj|
            CFG.windows[window.builder_name][obj.builder_name] = { "active=" => [obj.active?] } if [Gtk::RadioButton, Gtk::CheckButton].include?(obj.class)
            CFG.windows[window.builder_name][obj.builder_name] = { "text=" => [obj.text] }  if obj.class == Gtk::Entry
            CFG.windows[window.builder_name][obj.builder_name] = { "current_folder=" => [obj.current_folder] } if obj.class == Gtk::FileChooserButton
        end
    end

    def restore_window_content(glade, window)
        return if CFG.windows[window.builder_name].nil?
        CFG.windows[window.builder_name].each do |obj, msg|
            msg.each { |method, params| glade[obj].send(method.to_sym, *params) }
        end
    end


    #
    # Menu config (waiting to find how to discover menus when looping through a window's children
    #

    def save_menu_state(mw, menu)
        CFG.menus[menu.builder_name] = {}
        menu.each { |child|
            CFG.menus[menu.builder_name][child.builder_name] = { "active=" => [child.active?] } if child.is_a?(Gtk::CheckMenuItem) || child.is_a?(Gtk::RadioMenuItem)
        }
    end

    def load_menu_state(mw, menu)
        return if CFG.menus[menu.builder_name].nil?
        CFG.menus[menu.builder_name].each do |obj, msg|
            msg.each { |method, params| mw.glade[obj].send(method.to_sym, *params) }
        end
    end


    #
    # Window content save/restore to/from yaml (only used by the filter window)
    #

    FILTER = "filter"

    def yaml_from_content(gtk_object)
        yml = { FILTER => {} }

        objs = []
        child_controls(gtk_object, [Gtk::Expander], objs).each { |obj|
            yml[FILTER][obj.builder_name] = { "expanded=" => [obj.expanded?] }
        }

        objs = []
        child_controls(gtk_object, [Gtk::Entry, Gtk::CheckButton, Gtk::SpinButton, Gtk::ComboBox, Gtk::TreeView], objs).each do |obj|
            if (obj.class == Gtk::TreeView)
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

    def content_from_yaml(glade, yaml_str)
        yml = YAML.load(yaml_str)
        yml[FILTER].each do |obj, msg|
            msg.each do |method, params|
                if method == "items"
                    params[0].bytes.each_with_index { |byte, i| glade[obj].model.get_iter(i.to_s)[0] = byte == 49 } # ascii '1'
                else
                    glade[obj].send(method.to_sym, *params)
                end
            end
        end
    end
end

PREFS = Prefs.instance
