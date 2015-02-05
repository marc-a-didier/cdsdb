
module Prefs

    OBJ_SETTER_GETTER = { Gtk::Expander          => ['expanded=', :expanded?],
                          Gtk::CheckButton       => ['active=', :active?],
                          Gtk::RadioButton       => ['active=', :active?],
                          Gtk::ComboBox          => ['active=', :active],
                          Gtk::Entry             => ['text=', :text],
                          Gtk::SpinButton        => ['value=', :value],
                          Gtk::HPaned            => ['position=', :position],
                          Gtk::VPaned            => ['position=', :position],
                          Gtk::FileChooserButton => ['current_folder=', :current_folder],
                          Gtk::TreeView          => ['items', nil]
                        }

    def self.getter(klass)
        return OBJ_SETTER_GETTER[klass][1]
    end

    def self.setter(klass)
        return OBJ_SETTER_GETTER[klass][0]
    end

    #
    # Fills the array 'objects' with children of 'klass' type by recursively scanning the
    # gtk object 'object'
    #
    def self.child_controls(object, klass, objects)
        objects << object if object.class == klass
        object.children.each { |child| child_controls(child, klass, objects) } if object.respond_to?(:children)
        return objects
    end

    #
    # Windows size & positionning related funcs
    #
    #

    def self.restore_window(gtk_id)
        return if Cfg.windows[gtk_id].nil?
        Cfg.windows[gtk_id].each do |obj, msg|
            msg.each { |method, params| GtkUI[obj].send(method.to_sym, *params) if GtkUI[obj] }
        end
    end


    def self.save_window(gtk_id)
        window = GtkUI[gtk_id]

        Cfg.windows[window.builder_name] = { window.builder_name => { "move" => window.position,
                                                                      "resize" => window.size } }

        klasses = [Gtk::HPaned, Gtk::VPaned]
        klasses << Gtk::Expander unless gtk_id == GtkIDs::FILTER_WINDOW
        klasses.each do |klass|
            child_controls(window, klass, Array.new).each do |obj|
                Cfg.windows[window.builder_name][obj.builder_name] = { setter(klass) => obj.send(getter(klass)) }
            end
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


        [Gtk::Entry, Gtk::RadioButton, Gtk::CheckButton, Gtk::FileChooserButton].each do |klass|
            child_controls(window, klass, Array.new).each do |obj|
                Cfg.windows[window.builder_name][obj.builder_name] = { setter(klass) => obj.send(getter(klass)) }
            end
        end
    end


    #
    # Menu config (waiting to find how to discover menus when looping through a window's children
    #

    def self.save_menu_state(menu)
        Cfg.menus[menu.builder_name] = {}
        menu.each do |child|
            if child.is_a?(Gtk::CheckMenuItem) || child.is_a?(Gtk::RadioMenuItem)
                Cfg.menus[menu.builder_name][child.builder_name] = { "active=" => child.active? }
            end
        end
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

    def self.json_from_content(gtk_object)
        hash = { FILTER => {} }

        [Gtk::Expander, Gtk::Entry, Gtk::CheckButton, Gtk::SpinButton, Gtk::ComboBox, Gtk::TreeView].each do |klass|
            child_controls(gtk_object, klass, Array.new).each do |obj|
                if getter(klass) == nil
                    items = ""
                    obj.model.each { |model, path, iter| items << (iter[0] ? "1" : "0") }
                    hash[FILTER][obj.builder_name] = { setter(klass) => items }
                else
                    hash[FILTER][obj.builder_name] = { setter(klass) => obj.send(getter(klass)) }
                end
            end
        end

        return Psych.to_json(hash).gsub(/\n| /, "")
    end

    def self.content_from_json(json_str)
        hash = Psych.load(json_str)
        hash[FILTER].each do |obj, msg|
            msg.each do |method, params|
                if method == "items"
                    params.bytes.each_with_index { |byte, i| GtkUI[obj].model.get_iter(i.to_s)[0] = byte == 49 } # ascii '1'
                else
                    GtkUI[obj].send(method.to_sym, *params)
                end
            end
        end
    end
end
