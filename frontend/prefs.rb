
class Prefs

    include Singleton

    def initialize
        if File.exists?(CFG.prefs_file)
            @yml = YAML.load_file(CFG.prefs_file)
        else
            @yml = { "dbversion" => "6.0", "windows" => {}, "menus" => {} }
        end
    end

    def save
        File.open(CFG.prefs_file, "w") { |file| file.puts(@yml.to_yaml) }
    end


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
        return if @yml["windows"][name].nil?
        @yml["windows"][name].each do |obj, msg|
            msg.each { |method, params| glade[obj].send(method.to_sym, *params) }
        end
    end

    def load_window(top_window)
        return if @yml["windows"][top_window.window.builder_name].nil?
        @yml["windows"][top_window.window.builder_name].each do |obj, msg|
            msg.each { |method, params| top_window.mc.glade[obj].send(method.to_sym, *params) }
        end
    end

    def save_window(top_window)
        window = top_window.kind_of?(TopWindow) ? top_window.window : top_window

        @yml["windows"][window.builder_name] = { window.builder_name => { "move" => window.position, "resize" => window.size } }

        objs = []
        child_controls(window, [Gtk::HPaned, Gtk::VPaned], objs).each { |obj|
            @yml["windows"][window.builder_name][obj.builder_name] = { "position=" => [obj.position] }
        }

        unless top_window.class == FilterWindow
            objs = []
            child_controls(window, [Gtk::Expander], objs).each { |obj|
                @yml["windows"][window.builder_name][obj.builder_name] = { "expanded=" => [obj.expanded?] }
            }
        end

#         save
    end

    def save_windows(win_list)
        win_list.each { |window| save_window(window) if window.window.visible? }
    end

    def yaml_from_content(gtk_object)
        yml = { "filter" => {} }

        objs = []
        child_controls(gtk_object, [Gtk::Expander], objs).each { |obj|
            yml["filter"][obj.builder_name] = { "expanded=" => [obj.expanded?] }
        }

        objs = []
        child_controls(gtk_object, [Gtk::Entry, Gtk::CheckButton, Gtk::SpinButton, Gtk::ComboBox, Gtk::TreeView], objs).each do |obj|
            if (obj.class == Gtk::TreeView)
                items = ""
                obj.model.each { |model, path, iter| items << (iter[0] ? "1" : "0") }
                yml["filter"][obj.builder_name] = { "items" => [items] }
                next
            end
            yml["filter"][obj.builder_name] = { "active=" => [obj.active?] } if obj.class == Gtk::CheckButton
            yml["filter"][obj.builder_name] = { "active=" => [obj.active] } if obj.class == Gtk::ComboBox
            yml["filter"][obj.builder_name] = { "text=" => [obj.text] } if obj.class == Gtk::Entry
            yml["filter"][obj.builder_name] = { "value=" => [obj.value] } if obj.class == Gtk::SpinButton
        end

        return yml.to_yaml.gsub(/\n/, '\n')
    end

    def content_from_yaml(glade, yaml_str)
        yml = YAML.load(yaml_str)
# puts yml.to_yaml
        yml["filter"].each do |obj, msg|
            msg.each do |method, params|
                if method == "items"
                    params[0].bytes.each_with_index { |byte, i| glade[obj].model.get_iter(i.to_s)[0] = byte == 49 } # ascii '1'
                else
                    glade[obj].send(method.to_sym, *params)
                end
            end
        end
        return
    end

    #
    # Windows content related funcs
    #

    def save_window_objects(window)
        @yml["windows"][window.builder_name] = {}

        object_list = []
        child_controls(window, [Gtk::Entry, Gtk::RadioButton, Gtk::CheckButton, Gtk::FileChooserButton], object_list).each do |obj|
            @yml["windows"][window.builder_name][obj.builder_name] = { "active=" => [obj.active?] } if [Gtk::RadioButton, Gtk::CheckButton].include?(obj.class)
            @yml["windows"][window.builder_name][obj.builder_name] = { "text=" => [obj.text] }  if obj.class == Gtk::Entry
            @yml["windows"][window.builder_name][obj.builder_name] = { "current_folder=" => [obj.current_folder] } if obj.class == Gtk::FileChooserButton
        end

#         save
    end

    def restore_window_content(glade, window)
        return if @yml["windows"][window.builder_name].nil?
        @yml["windows"][window.builder_name].each do |obj, msg|
            msg.each { |method, params| glade[obj].send(method.to_sym, *params) }
        end
    end


    #
    # Menu config (waiting to find how to discover menus when looping through a window's children
    #

    def save_menu_state(mw, menu)
        @yml["menus"][menu.builder_name] = {}
        menu.each { |child|
            @yml["menus"][menu.builder_name][child.builder_name] = { "active=" => [child.active?] } if child.class == Gtk::CheckMenuItem
        }
#         save
    end

    def load_menu_state(mw, menu)
        return if @yml["menus"][menu.builder_name].nil?
        @yml["menus"][menu.builder_name].each do |obj, msg|
            msg.each { |method, params| mw.glade[obj].send(method.to_sym, *params) }
        end
    end


    def save_db_version(version)
        CFG.db_version = version
        @yml["dbversion"] = version
#         save
    end

end

PREFS = Prefs.instance
