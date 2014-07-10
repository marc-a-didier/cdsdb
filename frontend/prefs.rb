
class Prefs

    include Singleton

    def initialize
#         @file_name = CFG.prefs_file
#         File.exists?(@file_name) ? File.open(@file_name) { |file| @xdoc = REXML::Document.new(file) } : @xdoc = REXML::Document.new
#         if @xdoc.root.nil?
#             @xdoc << REXML::XMLDecl.new("1.0", "UTF-8", "no")
#             @xdoc.add_element("cdsdb", {"version" => 1})
#             @xdoc.root.add_element("database", {"version" => CFG.db_version})
#             @xdoc.root << REXML::Element.new("windows")
#             @xdoc.root << REXML::Element.new("menus")
#         end

        if File.exists?(CFG.prefs_file)
            @yml = YAML.load_file(CFG.prefs_file)
        else
            @yml = { "dbversion" => "6.0", "windows" => {}, "menus" => {} }
        end
        #puts @xdoc
    end

    def save
#         File.open(@file_name, "w") { |file| MyFormatter.new.write(@xdoc, file) }
        File.open("./prefs.yml", "w") { |file| file.puts(@yml.to_yaml) }
    end


    #
    # Fills the array 'object_list' of objects of 'object_types' type by recursively scanning the
    # object 'object'
    #
    def get_child_controls(object, object_types, object_list)
        object_list << object if object_types.include?(object.class)
        object.children.each { |child| get_child_controls(child, object_types, object_list) } if object.respond_to?(:children)
    end

    def child_controls(object, object_types, object_list)
        object_list << object if object_types.include?(object.class)
        object.children.each { |child| get_child_controls(child, object_types, object_list) } if object.respond_to?(:children)
        return object_list
    end

    #
    # Windows size & positionning related funcs
    #
    #

#     def load_main(glade, name)
#         return if REXML::XPath.first(@xdoc.root, "windows/"+name).nil?
#         REXML::XPath.first(@xdoc.root, "windows/"+name).each_element { |elm|
#             cmd = "glade['#{elm.name}'].send(:#{elm.attributes['method']}, #{elm.attributes['params']})"
#             eval(cmd)
#         }
#     end

    def load_window(top_window)
        return if @yml["windows"][top_window.window.builder_name].nil?
        @yml["windows"][top_window.window.builder_name].each do |obj, msg|
            msg.each { |method, params| top_window.mc.glade[obj].send(method.to_sym, *params) }
        end
    end

    def load_windows(glade, win_list)
        win_list.each { |window| load_window(glade, window) }
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
            get_child_controls(window, [Gtk::Expander], objs)
            objs.each { |obj| @yml["windows"][window.builder_name][obj.builder_name] = { "expanded=" => [obj.expanded?] } }
        end

        save
    end

    def save_windows(win_list)
        win_list.each { |window| save_window(window) }
    end

    def xdoc_from_content(gtk_object)
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

    def content_from_xdoc(glade, xdoc)
        yml = YAML.load(xdoc)
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

        save
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
        save
    end

    def load_menu_state(mw, menu)
        return if @yml["menus"][menu.builder_name].nil?
        @yml["menus"][menu.builder_name].each do |obj, msg|
            msg.each { |method, params| mw.glade[obj].send(method.to_sym, *params) }
        end
    end


    def save_db_version(version)
        CFG.db_version = version
#         @xdoc.root.elements["database"].attributes["version"] = "#{version}"
        @yml["dbversion"] = version
        save
    end

end

PREFS = Prefs.instance
