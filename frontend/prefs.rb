
class Prefs

    include Singleton

    def initialize
        @file_name = CFG.prefs_file
        File.exists?(@file_name) ? File.open(@file_name) { |file| @xdoc = REXML::Document.new(file) } : @xdoc = REXML::Document.new
        if @xdoc.root.nil?
            @xdoc << REXML::XMLDecl.new("1.0", "UTF-8", "no")
            @xdoc.add_element("cdsdb", {"version" => 1})
            @xdoc.root.add_element("database", {"version" => CFG.db_version})
            @xdoc.root << REXML::Element.new("windows")
            @xdoc.root << REXML::Element.new("menus")
        end
        #puts @xdoc
    end

    def save
        File.open(@file_name, "w") { |file| REXML::Formatters::Pretty.new.write(@xdoc, file) }
    end


    #
    # Fills the array 'object_list' of objects of 'object_types' type by recursively scanning the
    # object 'object'
    #
    def get_child_controls(object, object_types, object_list)
        object_list << object if object_types.include?(object.class)
        object.children.each { |child| get_child_controls(child, object_types, object_list) } if object.respond_to?(:children)
    end

    #
    # Windows size & positionning related funcs
    #
    #

    def load_main(glade, name)
        return if REXML::XPath.first(@xdoc.root, "windows/"+name).nil?
        REXML::XPath.first(@xdoc.root, "windows/"+name).each_element { |elm|
            cmd = "glade['#{elm.name}'].send(:#{elm.attributes['method']}, #{elm.attributes['params']})"
            eval(cmd)
        }
    end

    def load_window(top_window)
        return if REXML::XPath.first(@xdoc.root, "windows/"+top_window.window.builder_name).nil?
        REXML::XPath.first(@xdoc.root, "windows/"+top_window.window.builder_name).each_element { |elm|
            next if top_window.mc.glade[elm.name].nil?
            if elm.attributes['item']
                top_window.mc.glade[elm.name].model.get_iter(elm.attributes['item'])[0] = true
            else
                cmd = "top_window.mc.glade['#{elm.name}'].send(:#{elm.attributes['method']}, "
                if elm.attributes['method'] == "text="
                    cmd += "'"+elm.attributes['params']+"')"
                else
                    cmd += elm.attributes['params']+")"
                end
                eval(cmd)
            end
        }
    end

    def load_windows(glade, win_list)
        win_list.each { |window| load_window(glade, window) }
    end

    def save_window(top_window)
        window = top_window.kind_of?(TopWindow) ? top_window.window : top_window

        @xdoc.root.delete_element("windows/"+window.builder_name)
        REXML::XPath.first(@xdoc.root, "windows") << win = REXML::Element.new(window.builder_name)
        win.add_element(window.builder_name, {"method" => "move", "params" => window.position[0].to_s+","+window.position[1].to_s})
        win.add_element(window.builder_name, {"method" => "resize", "params" => window.size[0].to_s+","+window.size[1].to_s})

        objs = []
        get_child_controls(window, [Gtk::HPaned, Gtk::VPaned], objs)
        objs.each { |obj| win.add_element(obj.builder_name, {"method" => "position=", "params" => obj.position.to_s}) }

        objs = []
        get_child_controls(window, [Gtk::Expander], objs)
        objs.each { |obj| win.add_element(obj.builder_name, {"method" => "expanded=", "params" => obj.expanded?.to_s}) }

        if top_window.class == FilterWindow
            object_list = []
            get_child_controls(window, [Gtk::Entry, Gtk::CheckButton, Gtk::SpinButton, Gtk::ComboBox, Gtk::TreeView], object_list)

            object_list.each { |object|
                if (object.class == Gtk::TreeView)
                    object.model.each { |model, path, iter| win.add_element(object.builder_name, { "item" => path }) if iter[0] }
                    next
                end
                win.add_element(object.builder_name, {"method" => "active=", "params" => object.active?.to_s}) if object.class == Gtk::CheckButton
                win.add_element(object.builder_name, {"method" => "active=", "params" => object.active.to_s}) if object.class == Gtk::ComboBox
                win.add_element(object.builder_name, {"method" => "text=", "params" => object.text}) if object.class == Gtk::Entry
                win.add_element(object.builder_name, {"method" => "value=", "params" => object.value.to_s}) if object.class == Gtk::SpinButton
            }
        end

        save
    end

    def save_windows(win_list)
        win_list.each { |window| save_window(window) }
    end

    #
    # Windows content related funcs
    #

    def save_window_objects(window)
        object_list = []
        get_child_controls(window, [Gtk::Entry, Gtk::RadioButton, Gtk::CheckButton, Gtk::FileChooserButton], object_list)

        @xdoc.root.delete_element("windows/"+window.builder_name)
        REXML::XPath.first(@xdoc.root, "windows") << win = REXML::Element.new(window.builder_name)

        object_list.each { |object|
            win.add_element(object.builder_name, {"method" => "active=", "params" => object.active?.to_s}) if [Gtk::RadioButton, Gtk::CheckButton].include?(object.class)
            win.add_element(object.builder_name, {"method" => "text=", "params" => object.text}) if object.class == Gtk::Entry
            win.add_element(object.builder_name, {"method" => "current_folder=", "params" => object.current_folder}) if object.class == Gtk::FileChooserButton
        }

        save
    end

    def restore_window_content(glade, window)
        return if REXML::XPath.first(@xdoc.root, "windows/"+window.builder_name).nil?
        REXML::XPath.first(@xdoc.root, "windows/"+window.builder_name).each_element { |elm|
            next if glade[elm.name].nil?
            if elm.attributes['method'] == "text=" || elm.attributes['method'] == "current_folder="
                cmd = "glade['#{elm.name}'].send(:#{elm.attributes['method']},'#{elm.attributes['params']}')"
            else
                cmd = "glade['#{elm.name}'].send(:#{elm.attributes['method']},#{elm.attributes['params']})"
            end
            eval(cmd)
        }
    end


    #
    # Menu config (waiting to find how to discover menus when looping through a window's children
    #

    def save_menu_state(mw, menu)
        @xdoc.root.delete_element("menus/"+menu.builder_name)
        REXML::XPath.first(@xdoc.root, "menus") << mnu = REXML::Element.new(menu.builder_name)
        menu.each { |child|
            mnu.add_element(child.builder_name, {"method" => "active=", "params" => child.active?.to_s}) if child.class == Gtk::CheckMenuItem
        }
        save
    end

    def load_menu_state(mw, menu)
        return if REXML::XPath.first(@xdoc.root, "menus/"+menu.builder_name).nil?
        REXML::XPath.first(@xdoc.root, "menus/"+menu.builder_name).each_element { |elm|
            mw.glade[elm.name].send(elm.attributes['method'].to_sym, elm.attributes['params'] == 'true') if mw.glade[elm.name]
        }
    end


    def save_db_version(version)
        CFG.db_version = version
        @xdoc.root.elements["database"].attributes["version"] = "#{version}"
        save
    end

end

PREFS = Prefs.instance
