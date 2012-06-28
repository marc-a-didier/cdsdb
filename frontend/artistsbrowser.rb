
#
# TODO: remplacer All par filtered et appliquer le filtre seulement sur cette branche???

class GenRowProp

    attr_accessor :ref, :table, :max_level, :filtered, :where_fields, :title

    def initialize(ref, table, max_level, filtered, where_fields, title)
        @ref = ref
        @table = table
        @max_level = max_level
        @filtered = filtered
        @where_fields = where_fields
        @title = title
    end

    def select_for_level(level, iter, mc, model)
        if level == 0
            return "SELECT * FROM #{iter[2].table}"
        else
            raise
        end
    end

    # Add a fake child setting its ref to -1 so we're sure it's always the
    # first child since db refs are always positive.
    def append_fake_child(model, iter)
        fake = model.append(iter)
        fake[0] = -1
    end

    # By default, post_select removes the first child which is the fake child.
    def post_select(model, iter, mc)
        model.remove(iter.first_child)
    end

    def sub_filter(iter)
        return " #{@where_fields}=#{iter.parent[0]} "
    end
end

class GenresRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = "SELECT * FROM #{iter[2].table}"
        elsif level == 1
            if mc.view_compile?
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN records ON records.rartist = artists.rartist
                         WHERE records.rgenre=#{iter[0]}}
            else
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN segments ON segments.rartist = artists.rartist
                         INNER JOIN records ON records.rrecord = segments.rrecord
                         WHERE records.rgenre=#{iter[0]}}
            end
        end
        return sql
    end
end

class LabelsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = "SELECT * FROM #{iter[2].table}"
        elsif level == 1
            if mc.view_compile?
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN records ON records.rartist = artists.rartist
                         WHERE records.rlabel=#{iter[0]}}
            else
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN segments ON segments.rartist = artists.rartist
                         INNER JOIN records ON records.rrecord = segments.rrecord
                         WHERE records.rlabel=#{iter[0]}}
            end
        end
        return sql
    end
end

class OriginsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = "SELECT * FROM #{iter[2].table}"
        elsif level == 1
#             if mc.view_compile?
#                 sql = "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
#                        "INNER JOIN records ON artists.rartist=records.rartist " \
#                        "WHERE artists.rorigin=#{iter[0]}"
#             else
                sql = %Q{SELECT artists.rartist, artists.sname FROM artists
                         WHERE artists.rorigin=#{iter[0]}}
#             end
        end
        return sql
    end
end

class AllArtistsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if mc.view_compile?
            sql = "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                    "INNER JOIN records ON artists.rartist=records.rartist " \
                    "INNER JOIN segments ON segments.rrecord=records.rrecord " \
                    "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
        else
            sql =  "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                    "INNER JOIN segments ON segments.rartist=artists.rartist " \
                    "INNER JOIN records ON records.rrecord=segments.rrecord " \
                    "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
        end
        sql += "WHERE "+mc.main_filter.gsub(/^ AND/, "") unless mc.main_filter.empty?
        return sql
    end

    def post_select(model, iter, mc)
        # If not showing compile, we must add the Compilations anyway or the show record
        # in browser feature from various popups/buttons won't work
        unless mc.view_compile?
            child = model.append(iter)
            child[0], child[1], child[2], child[3] = 0, "Compilations", iter[2], "Compilations"
        end
        super(model, iter, mc)
    end

    def sub_filter(iter)
        return ""
    end
end

class TagsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            UIConsts::TAGS.each_with_index { |tag, i|
                child = model.append(iter)
                child[0] = i
                child[1] = "<i>#{tag}</i>"
                child[2] = iter[2]
                child[3] = tag
                append_fake_child(model, child)
            }
            sql = ""
        elsif level == 1
            if mc.view_compile?
                sql = "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                        "INNER JOIN records ON artists.rartist=records.rartist " \
                        "INNER JOIN segments ON segments.rrecord=records.rrecord " \
                        "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
            else
                sql =  "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                        "INNER JOIN segments ON segments.rartist=artists.rartist " \
                        "INNER JOIN records ON records.rrecord=segments.rrecord " \
                        "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
            end
            sql += "WHERE (tracks.itags & #{1 << iter[0]}) <> 0"
        end
        return sql
    end

    def sub_filter(iter)
        return " (#@where_fields & #{1 << iter.parent[0]}) <> 0 "
    end
end

class RippedRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = %Q{SELECT records.idateripped, artists.rartist, artists.sname, records.rrecord, records.stitle FROM artists
                     INNER JOIN records ON records.rartist = artists.rartist
                     WHERE records.idateripped <> 0
                     ORDER BY records.idateripped DESC LIMIT 100;}
            count = 0
            DBIntf::connection.execute(sql) { |row|
                child = model.append(iter)
                child[0] = row[1]
                child[1] = Time.at(row[0]).strftime("%d.%m.%Y")+" - "
                child[1] += row[1] == 0 ? CGI::escapeHTML(row[4]) : CGI::escapeHTML(row[2])
                child[2] = iter[2]
                child[3] = ("%03d" % count)+row[3].to_s
                count += 1
            }
        end
        return ""
    end

    def sub_filter(iter)
        return " #@where_fields = #{iter[3][3..-1].to_i}" # Extract rrecord from the sort column
    end
end

class ArtistsBrowser < GenericBrowser

    MB_TOP_LEVELS = [AllArtistsRowProp.new(1, "artists", 1, false, "", "All"),
                     GenresRowProp.new(2, "genres", 2, true, "records.rgenre", "Genres"),
                     OriginsRowProp.new(3, "origins", 2, true, "artists.rorigin", "Countries"),
                     TagsRowProp.new(4, "tags", 2, true, "tracks.itags", "Tags"),
                     LabelsRowProp.new(5, "labels", 2, true, "records.rlabel", "Labels"),
                     RippedRowProp.new(6, "artists", 1, false, "records.rrecord", "Last ripped")]
# TODO: add by rating  LabelsRowProp.new(5, "labels", 2, true, "records.rlabel", "Labels")]

    ATV_REF   = 0
    ATV_NAME  = 1
    ATV_CLASS = 2
    ATV_SORT  = 3

    ROW_REF     = 0
    ROW_NAME    = 1

    attr_reader :artist

    def initialize(mc)
        super(mc, mc.glade[UIConsts::ARTISTS_TREEVIEW])
        @artist = ArtistUI.new(@mc.glade)
        @seg_art = ArtistUI.new(@mc.glade)
    end

    def setup
        name_renderer = Gtk::CellRendererText.new
        if Cfg::instance.admin?
            name_renderer.editable = true
            name_renderer.signal_connect(:edited) { |widget, path, new_text| on_artist_edited(widget, path, new_text) }
        end
        name_column = Gtk::TreeViewColumn.new("Name", name_renderer)
        name_column.set_cell_data_func(name_renderer) { |col, renderer, model, iter| renderer.markup = iter[ATV_NAME] }

        @tv.append_column(Gtk::TreeViewColumn.new("Ref.", Gtk::CellRendererText.new, :text => ATV_REF))
        @tv.append_column(name_column)

        @tv.columns[ATV_NAME].resizable = true

        @tvm = Gtk::TreeStore.new(Integer, String, Class, String)

        @tvs = nil # Intended to be a shortcut to @tv.selection.selected. Set in selection change

        @tv.selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        @tv.signal_connect(:button_press_event) { |widget, event|
            show_popup(widget, event, UIConsts::ART_POPUP_MENU) if @tvs && @tvm.iter_depth(@tvs) == @tvs[2].max_level
        }

        @tv.signal_connect(:row_expanded) { |widget, iter, path| on_row_expanded(widget, iter, path) }

#         @tv.set_row_separator_func { |model, iter|
#             model.iter_depth(iter) < iter[2].max_level
#         }

        @mc.glade[UIConsts::ART_POPUP_ADD].signal_connect(:activate)   { on_art_popup_add   }
        @mc.glade[UIConsts::ART_POPUP_DEL].signal_connect(:activate)   { on_art_popup_del   }
        @mc.glade[UIConsts::ART_POPUP_EDIT].signal_connect(:activate)  { edit_artist        }
        @mc.glade[UIConsts::ART_POPUP_INFOS].signal_connect(:activate) { show_artists_infos }

        return super
    end

    def load_entries
        @tvm.clear
        MB_TOP_LEVELS.each { |entry|
            iter = @tvm.append(nil)
            iter[0] = entry.ref
            iter[1] = "<b>#{entry.title}</b>"
            iter[2] = entry
            iter[3] = entry.title
            entry.append_fake_child(@tvm, iter)
            load_sub_tree(iter) if entry.ref == 1 # Load subtree if all artists
        }
        @tv.model = @tvm
        @tvm.set_sort_column_id(3, Gtk::SORT_ASCENDING)

        return self
    end

    def reload
        load_entries
        @mc.no_selection if position_to(@artist.rartist).nil?
        return self
    end

    def edit_artist
        DBEditor.new(@mc, @artist).run if @artist.valid?
    end

    # Recursively search for rartist from iter. If iter is nil, search from tree root.
    # !!! iter.next! returns true if set to next iter and false if no next iter
    #     BUT iter itself is reset to iter_first => iter is NOT nil
    def select_artist(rartist, iter = nil)
        iter = @tvm.iter_first unless iter
        if iter.has_child?
            if iter.first_child[0] != -1
                self.select_artist(rartist, iter.first_child)
            else
                self.select_artist(rartist, iter) if iter.next!
            end
        else
            while iter[0] != rartist
                return unless iter.next!
            end
            @tv.expand_row(iter.parent.path, false) unless @tv.row_expanded?(iter.parent.path)
            @tv.set_cursor(iter.path, nil, false)
        end
    end

    def map_sub_row_to_entry(row, iter)
        new_child = @tvm.append(iter)
        new_child[0] = row[0]
        new_child[1] = CGI::escapeHTML(row[1])
        new_child[2] = iter[2]
        new_child[3] = row[1]
        if @tvm.iter_depth(new_child) < iter[2].max_level
            new_child[1] = "<i>#{new_child[1]}</i>"
            iter[2].append_fake_child(@tvm, new_child)
        end
    end

    # Load children of iter. If it has childen and first child ref is not -1 the children
    # are already loaded, so do nothing except if force_reload is set to true.
    # If first child ref is -1, it's a fake entry so load the true children
    def load_sub_tree(iter, force_reload = false)

        return if iter.first_child && iter.first_child[0] != -1 && !force_reload

puts "*** load new sub tree ***"
        # Making the first column the sort column greatly speeds up things AND makes sure that the
        # fake item is first in the store.
        @tvm.set_sort_column_id(0)

        # Remove all children EXCEPT the first one, it's a gtk treeview requirement!!!
        # If not force_reload, we have just one child, the fake entry, so don't remove it now
        remove_children_but_first(iter) if force_reload

        sql = iter[2].select_for_level(@tvm.iter_depth(iter), iter, @mc, @tvm)

        DBIntf::connection.execute(sql) { |row| map_sub_row_to_entry(row, iter) } unless sql.empty?

        # Perform any post selection required action. By default, removes the first fake child
        iter[2].post_select(@tvm, iter, @mc)

        iter[1] = iter[1]+" - (#{iter.n_children})"

        @tvm.set_sort_column_id(3, Gtk::SORT_ASCENDING)
    end

    def on_row_expanded(widget, iter, path)
        load_sub_tree(iter)
    end

    def on_selection_changed(widget)
        @tvs = @tv.selection.selected
        if @tvs.nil? || @tvm.iter_depth(@tvs) < @tvs[2].max_level
            @artist.reset
        else
            @artist.ref_load(@tvs[ATV_REF])
        end
        @artist.to_widgets
        @artist.valid? ? @mc.artist_changed : @mc.invalidate_tabs
    end

    def sub_filter
        # TODO -> return @tvs.nil? ? "" : @tvs[2].sub_filter(@tvs)
        return "" if @tvs.nil?
        if @tvs[2].where_fields.empty? || @tvm.iter_depth(@tvs) < @tvs[2].max_level
            return ""
        else
            return @tvs[2].sub_filter(@tvs)
        end
    end

    def on_art_popup_add
        @artist.add_new
        load_entries.position_to(@artist.rartist)
    end

    def on_art_popup_del
        @tvm.remove(@tvs) if UIUtils::delete_artist(@tvs[ATV_REF]) == 0 if !@tvs.nil? && UIUtils::get_response("Sure to delete this artist?") == Gtk::Dialog::RESPONSE_OK
    end

    def on_art_popup_edit
        @tv.set_cursor(@tvs.path, @tv.columns[ATV_NAME], true) if @tvs
    end

    def on_artist_edited(widget, path, new_text)
        if @tvs[ATV_NAME] != new_text
            @tvs[ATV_NAME] = new_text
            @artist.sname = new_text
            @artist.sql_update.to_widgets
        end
    end

    def update_segment_artist(rartist)
        @seg_art.ref_load(rartist).to_widgets
    end

    def show_artists_infos
        recs_infos = DBIntf::connection.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(records.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN tracks ON tracks.rrecord=records.rrecord
               WHERE rartist=#{@tvs[0]};})
        comp_infos = DBIntf::connection.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(segments.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN segments ON segments.rrecord=records.rrecord
               INNER JOIN tracks ON tracks.rsegment=segments.rsegment
               WHERE segments.rartist=#{@tvs[0]} AND records.rartist=0;})

        glade = GTBld::load(UIConsts::DLG_ART_INFOS)
        glade[UIConsts::ARTINFOS_LBL_RECS].text = recs_infos[0].to_s+" records, #{recs_infos[2]} tracks for "+Utils::format_day_length(recs_infos[1].to_i)
        glade[UIConsts::ARTINFOS_LBL_COMPILES].text = comp_infos[0].to_s+" compilations, #{comp_infos[2]} tracks for "+Utils::format_day_length(comp_infos[1].to_i)
        glade[UIConsts::DLG_ART_INFOS].show.run
        glade[UIConsts::DLG_ART_INFOS].destroy
    end

end
