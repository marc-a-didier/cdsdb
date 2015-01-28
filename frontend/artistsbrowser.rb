
#
# TODO: remplacer All par filtered et appliquer le filtre seulement sur cette branche???

#
# Generic Row Properties class.
#
# Parent class of all top levels rows displayed in the artist browser.
#
# To do its job, a row property subclass must override the select_for_level method
# to return the SQL statement needed to get its data displayed.
#
#
# The tree model is defined as:
#
#   Integer: Always the uid (or db primary key).
#
#   String:  The string displayed, may use html tags to make a fancier display .
#
#   Class:   A reference to the GenRowProp subclass of the top parent. When an iter is
#            given in parameter, it's safe to use iter[2] as a GenRowProp to get whatever
#            may be needed from the class.
#
#   String:  The string used to sort the tree view, usually the string from the SQL statement
#            plus anything that may be needed to obtain a correct order (see Records, Ripped).
#
#
class GenRowProp

    FAKE_ID = -10

    SELECT_ARTISTS = -1
    SELECT_RECORDS = -2

    attr_accessor :ref, :table, :max_level, :filtered, :where_fields, :title

    # In: ->ref         : uid for the row
    #     ->table       : the main db table name to work on
    #     ->max_level   : the numbers of levels of the row (1 means data directly under the row,
    #                     2 means one intermediate level between row and real data, etc...)
    #     ->filtered    : unused
    #     ->where_fields: the discriminating field on which the WHERE clause apply
    #     ->title       : the title displayed for the row
    def initialize(ref, table, max_level, filtered, where_fields, title)
        @ref = ref
        @table = table
        @max_level = max_level
        @filtered = filtered
        @where_fields = where_fields
        @title = title
    end

    #
    # Must return the appropriate SQL statement for the level given by... level
    #
    def select_for_level(level, iter, mc, model)
        raise
    end


    def default_main_select(where_clause = "")
        return "SELECT * FROM #{@table} "+where_clause
    end

    #
    # By default, filter on where_fields and the parent PK or grand-parent PK if view
    # is subdivided with artists/records
    #
    def default_filter(iter)
        iter.parent[0] < 0 ? " #{@where_fields}=#{iter.parent.parent[0]} " :
                             " #{@where_fields}=#{iter.parent[0]} "

    end


    #
    # Must return a condition for the WHERE clause for the given iter.
    #
    # By default, returns a filter on the discriminating field on its parent ID.
    #
    # Only needed for the real data level, not called for intermediate levels.
    #
    def sub_filter(iter)
        filter = default_filter(iter)
        if iter.parent[0] == SELECT_RECORDS
            filter += "AND records.rrecord=#{iter[3].split("@@@")[1]}" # Extract rrecord from the sort column
        end
        return filter
    end

    #
    # Called when the sub tree is filled, after the select_for_level call.
    #
    # By default removes the first child which is the fake child.
    #
    # May be overriden by subclasses.
    #
    def post_select(model, iter, mc)
        model.remove(iter.first_child)
    end

    #
    # Helpers
    #

    def add_compilations(model, iter, mc)
        if mc.view_compile? && iter[0] == SELECT_ARTISTS
            child = model.append(iter)
            child[0], child[1], child[2], child[3] = 0, "Compilations", iter[2], "Compilations"
        end
    end

    #
    # Add a fake child setting its ref to -10 so we're sure it's always the
    # first child since db refs are always positive.
    #
    def append_fake_child(model, iter)
        fake = model.append(iter)
        fake[0] = FAKE_ID
    end

    #
    # Adds Artists/Records children for views that want it
    #
    def append_artists_records(model, iter)
        ["Artists", "Records"].each_with_index { |title, index|
            child = model.append(iter)
            child[0], child[1], child[2], child[3] = -1-index, "<b>#{title}</b>", iter[2], title
            append_fake_child(model, child)
        }
        # The caller expects a SQL statement. Empty means nothing to do.
        return ""
    end

    #
    # Returns a SQL statement which makes the necessary joins.
    #
    # The statement needs to be completed by the subclass.
    #
    def get_select_on_tracks(mc, selection_type = SELECT_ARTISTS)
        if selection_type == SELECT_ARTISTS
            if mc.view_compile?
                return "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                        "INNER JOIN records ON artists.rartist=records.rartist " \
                        "INNER JOIN segments ON segments.rrecord=records.rrecord " \
                        "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
            else
                return "SELECT DISTINCT(artists.rartist), artists.sname FROM artists " \
                        "INNER JOIN segments ON segments.rartist=artists.rartist " \
                        "INNER JOIN records ON records.rrecord=segments.rrecord " \
                        "INNER JOIN tracks ON tracks.rsegment=segments.rsegment "
            end
        else
            return %Q{SELECT DISTINCT(records.stitle), artists.rartist, artists.sname, records.rrecord FROM records
                      INNER JOIN artists ON records.rartist = artists.rartist
                      INNER JOIN tracks ON tracks.rrecord = records.rrecord }
        end
    end


    #
    # Returns an SQL statement for records based filter
    #
    def get_select_on_records(mc, iter)
        if iter[0] == SELECT_ARTISTS
            if mc.view_compile?
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN records ON records.rartist = artists.rartist }
            else
                sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                         INNER JOIN segments ON segments.rartist = artists.rartist
                         INNER JOIN records ON records.rrecord = segments.rrecord }
            end
        else
            sql = %Q{SELECT DISTINCT(records.stitle), artists.rartist, artists.sname, records.rrecord FROM records
                     INNER JOIN artists ON records.rartist = artists.rartist }
        end
    end
end

#
# The main artists view that shows all artists.
#
# The only view that may be filtered using the filter window.
#
class AllArtistsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        sql = get_select_on_tracks(mc)
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

#
# View by genres, shows the genres at the first level and each artist for the genre.
#
class GenresRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        return case level
            when 0 then default_main_select("WHERE rgenre > 0")
            when 1 then append_artists_records(model, iter)
            when 2 then get_select_on_records(mc, iter)+"WHERE records.rgenre=#{iter.parent[0]}"
        end
    end
end

#
# View by labels, shows the labels at the first level and each artist for the label.
#
class LabelsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        return case level
            when 0 then default_main_select
            when 1 then append_artists_records(model, iter)
            when 2 then get_select_on_records(mc, iter)+"WHERE records.rlabel=#{iter.parent[0]}"
        end
    end
end

#
# View by origins, shows the origins at the first level and each artist for the origin.
#
class OriginsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        sql = ""
        if level == 0
            sql = default_main_select
        elsif level == 1
            append_artists_records(model, iter)
        elsif level == 2
            if iter[0] == SELECT_ARTISTS
                if mc.view_compile?
                    sql = %{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                            INNER JOIN records ON artists.rartist=records.rartist
                            WHERE artists.rorigin=#{iter.parent[0]}}
                else
                    sql = %{SELECT artists.rartist, artists.sname FROM artists
                            WHERE artists.rorigin=#{iter.parent[0]}}
                end
            else
                sql = %{SELECT DISTINCT(records.stitle), artists.rartist, artists.sname, records.rrecord FROM records
                        INNER JOIN artists ON records.rartist = artists.rartist
                        WHERE artists.rorigin=#{iter.parent[0]}}
            end
        end
        return sql
    end

    def post_select(model, iter, mc)
        add_compilations(model, iter, mc)
        super(model, iter, mc)
    end
end

#
# View by tags, shows the tags at the first level and each artist for the tag.
#
class TagsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        return case level
            when 0
                Qualifiers::TAGS.each_with_index { |tag, i|
                    child = model.append(iter)
                    child[0] = i
                    child[1] = tag.to_html_italic
                    child[2] = iter[2]
                    child[3] = tag
                    append_fake_child(model, child)
                }
                ""
            when 1 then append_artists_records(model, iter)
            when 2 then get_select_on_tracks(mc, iter[0])+"WHERE (tracks.itags & #{1 << iter.parent[0]}) <> 0"
        end
    end

    def default_filter(iter)
        return " (#@where_fields & #{1 << iter.parent.parent[0]}) <> 0 "
    end
end

#
# View the last 100 ripped records, sorted by date in a single level.
#
class RippedRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = %Q{SELECT records.idateripped, artists.rartist, artists.sname, records.rrecord, records.stitle FROM artists
                     INNER JOIN records ON records.rartist = artists.rartist
                     WHERE records.idateripped <> 0
                     ORDER BY records.idateripped DESC LIMIT 100;}
            count = 0
            DBIntf.execute(sql) { |row|
                child = model.append(iter)
                child[0] = row[1]
                child[1] = Time.at(row[0]).strftime("%d.%m.%Y")+" - "+
                           row[4].to_html_bold+"\nby "+row[2].to_html_italic
#                 child[1] += CGI::escapeHTML(row[row[1] == 0 ? 4 : 2])
                child[2] = iter[2]
                child[3] = ("%03d" % count)+row[3].to_s
                count += 1
            }
        end
        return ""
    end

    def sub_filter(iter)
        return " #@where_fields = #{iter[3][3..-1]}" # Extract rrecord from the sort column
    end
end

#
# View artists that have at least one never played track in a single level.
#
class NeverRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        return case level
            when 0 then append_artists_records(model, iter)
            when 1 then get_select_on_tracks(mc, iter[0])+"WHERE tracks.iplayed=0;"
        end
    end

    def default_filter(iter)
        return " #@where_fields=0 "
    end
end

#
# View by ratings, shows the ratings at the first level and each artist for the rating.
#
class RatingsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        return case level
            when 0
                Qualifiers::RATINGS.each_with_index { |rating, i|
                    child = model.append(iter)
                    child[0] = i
                    child[1] = rating.to_html_italic
                    child[2] = iter[2]
                    child[3] = i.to_s
                    append_fake_child(model, child)
                }
                ""
            when 1 then append_artists_records(model, iter)
            when 2 then get_select_on_tracks(mc, iter[0])+"WHERE tracks.irating=#{iter.parent[0]}"
        end
    end
end


#
# View by record length in 10 minutes increments.
#
class PTimeRowProp < GenRowProp

    TINC = 10*60*1000

    def select_for_level(level, iter, mc, model)
        return case level
            when 0
                (1..9).each { |i|
                    child = model.append(iter)
                    child[0] = i*TINC
                    child[1] = "Up to #{i*10} min.".to_html_italic
                    child[2] = iter[2]
                    child[3] = i.to_s
                    append_fake_child(model, child)
                }
                ""
            when 1 then append_artists_records(model, iter)
            when 2
                get_select_on_records(mc, iter)+
                        "WHERE records.iplaytime > #{iter.parent[0]-TINC} AND \
                               records.iplaytime <= #{iter.parent[0]}"
        end
    end

    def default_filter(iter)
        return " #@where_fields > #{iter.parent.parent[0]-TINC} AND \
                 #@where_fields <= #{iter.parent.parent[0]} "
    end
end

#
# View by records, a single level that shows all records.
#
# It leads to a strange view since each entry in the artist view is replicated in the
# records view. It's the only view that shows only one record for an artist. Also
# it doesn't care if the we view all artists or grouped in compilations.
#
# TODO: voir pour remplacer les magouilles par une classe/methode qui retourne le champ
#       sur lequel on doit trier et/ou filtrer!!!
#
class RecordsRowProp < GenRowProp
    def select_for_level(level, iter, mc, model)
        if level == 0
            sql = %Q{SELECT records.stitle, artists.rartist, artists.sname, records.rrecord FROM records
                     INNER JOIN artists ON records.rartist = artists.rartist;}
#                      ORDER BY LOWER(records.stitle);}
            DBIntf.execute(sql) { |row|
                child = model.append(iter)
                child[0] = row[1]
#                 child[1] = '<span color="green">'+CGI::escapeHTML(row[0])+"</span>\n<i>"+CGI::escapeHTML(row[2])+"</i>"
#                 child[1] = "<b>"+CGI::escapeHTML(row[0])+"</b>\nby <i>"+CGI::escapeHTML(row[2])+"</i>"
                child[1] = row[0].to_html_bold+"\nby "+row[2].to_html_italic
                child[2] = iter[2]
                child[3] = row[0]+"@@@"+row[3].to_s # Magouille magouille...
            }
        end
        return ""
    end

    def sub_filter(iter)
        return " #@where_fields = #{iter[3].split("@@@")[1]}" # Extract rrecord from the sort column
    end
end

class ArtistsBrowser < Gtk::TreeView

    # Initialize all top levels rows
    MB_TOP_LEVELS = [AllArtistsRowProp.new(1, "artists", 1, false, "", "All Artists"),
                     GenresRowProp.new(2, "genres", 3, true, "records.rgenre", "Genres"),
                     OriginsRowProp.new(3, "origins", 3, true, "artists.rorigin", "Countries"),
                     TagsRowProp.new(4, "tags", 3, true, "tracks.itags", "Tags"),
                     LabelsRowProp.new(5, "labels", 3, true, "records.rlabel", "Labels"),
                     RippedRowProp.new(6, "artists", 1, true, "records.rrecord", "Last ripped"),
                     NeverRowProp.new(7, "tracks", 2, true, "tracks.iplayed", "Never played"),
                     RatingsRowProp.new(8, "ratings", 3, true, "tracks.irating", "Rating"),
                     PTimeRowProp.new(9, "records", 3, true, "records.iplaytime", "Records play time"),
                     RecordsRowProp.new(10, "records", 1, true, "records.rrecord", "All Records")]

    ATV_REF   = 0
    ATV_NAME  = 1
    ATV_CLASS = 2
    ATV_SORT  = 3

    ROW_REF     = 0
    ROW_NAME    = 1

    attr_reader :artlnk

    def initialize
        super
        @artlnk = XIntf::Artist.new # Cache link for the current artist
        @seg_art = XIntf::Artist.new # Cache link used to update data when browsing a compilation
    end

    def setup(mc)
        @mc = mc
        GtkUI[GtkIDs::ARTISTS_TVC].add(self)
        self.visible = true
        self.enable_search = true
        self.search_column = 3

        selection.mode = Gtk::SELECTION_SINGLE

        name_renderer = Gtk::CellRendererText.new
#         if Cfg.admin?
#             name_renderer.editable = true
#             name_renderer.signal_connect(:edited) { |widget, path, new_text| on_artist_edited(widget, path, new_text) }
#         end
        name_column = Gtk::TreeViewColumn.new("Views", name_renderer)
        name_column.set_cell_data_func(name_renderer) { |col, renderer, model, iter| renderer.markup = iter[ATV_NAME] }

        append_column(Gtk::TreeViewColumn.new("Ref.", Gtk::CellRendererText.new, :text => ATV_REF))
        append_column(name_column)

        columns[ATV_NAME].resizable = true

        self.model = Gtk::TreeStore.new(Integer, String, Class, String)

        @tvs = nil # Intended to be a shortcut to @tv.selection.selected. Set in selection change

        selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        signal_connect(:button_press_event) { |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS || event.button == 3 # left mouse button
                [GtkIDs::ART_POPUP_ADD, GtkIDs::ART_POPUP_DEL,
                 GtkIDs::ART_POPUP_EDIT, GtkIDs::ART_POPUP_INFOS].each { |item|
                    GtkUI[item].sensitive = @tvs && model.iter_depth(@tvs) == @tvs[2].max_level
                }
                GtkUI[GtkIDs::ART_POPUP_REFRESH].sensitive = @tvs && model.iter_depth(@tvs) < @tvs[2].max_level
                show_popup(widget, event, GtkIDs::ART_POPUP_MENU) if @tvs
            end
        }

        # This line has NO effect when incremental search fails to find a string. The selection is empty...
        # @tv.selection.mode = Gtk::SELECTION_BROWSE

        signal_connect(:row_expanded) { |widget, iter, path| on_row_expanded(widget, iter, path) }
#         @tv.signal_connect(:key_press_event) { |widget, event|
#             searching = !@tv.search_entry.nil?;
#             puts "searching=#{searching}";
#             false }
#         @tv.signal_connect(:start_interactive_search) { |tv, data| puts "search started...".green }
# puts "search entry=#{@tv.search_entry}"
#         @tv.set_search_equal_func { |model, columnm, key, iter| puts "searching #{key}"; true }
#         @tv.set_row_separator_func { |model, iter|
#             model.iter_depth(iter) < iter[2].max_level
#         }

        GtkUI[GtkIDs::ART_POPUP_ADD].signal_connect(:activate)     { on_art_popup_add   }
        GtkUI[GtkIDs::ART_POPUP_DEL].signal_connect(:activate)     { on_art_popup_del   }
        GtkUI[GtkIDs::ART_POPUP_EDIT].signal_connect(:activate)    { edit_artist        }
        GtkUI[GtkIDs::ART_POPUP_INFOS].signal_connect(:activate)   { show_artists_infos }
        GtkUI[GtkIDs::ART_POPUP_REFRESH].signal_connect(:activate) { reload_sub_tree    }

        return finalize_setup
    end

    def load_entries
        model.clear
        MB_TOP_LEVELS.each { |entry|
            iter = model.append(nil)
            iter[0] = entry.ref
            iter[1] = entry.title.to_html_bold
            iter[2] = entry
            iter[3] = entry.title
            entry.append_fake_child(model, iter)
            load_sub_tree(iter) if entry.ref == 1 # Load subtree if all artists
        }
        model.set_sort_column_id(3, Gtk::SORT_ASCENDING)

        return self
    end

    def reload
        load_entries
        @mc.no_selection if !@artlnk.valid_artist_ref? || position_to(@artlnk.artist.rartist).nil?
        return self
    end

    def reload_sub_tree
        return if @tvs.nil? || model.iter_depth(@tvs) == @tvs[2].max_level
        load_sub_tree(@tvs, true)

    end

    def edit_artist
        @artlnk.to_widgets if @artlnk.valid_artist_ref? && XIntf::Editors::Main.new(@mc, @artlnk, XIntf::Editors::ARTIST_PAGE).run == Gtk::Dialog::RESPONSE_OK
    end

    # Recursively search for rartist from iter. If iter is nil, search from tree root.
    # !!! iter.next! returns true if set to next iter and false if no next iter
    #     BUT iter itself is reset to iter_first => iter is NOT nil
    def select_artist(rartist, iter = nil)
        iter = model.iter_first unless iter
        if iter.has_child?
            if iter.first_child[0] != GenRowProp::FAKE_ID
                self.select_artist(rartist, iter.first_child)
            else
                self.select_artist(rartist, iter) if iter.next!
            end
        else
            while iter[0] != rartist
                return unless iter.next!
            end
            expand_row(iter.parent.path, false) unless row_expanded?(iter.parent.path)
            set_cursor(iter.path, nil, false)
        end
    end

    def map_sub_row_to_entry(row, iter)
        new_child = model.append(iter)
        if iter[0] == GenRowProp::SELECT_RECORDS
            new_child[0] = row[1]
            new_child[1] = row[0].to_html_bold+"\nby "+row[2].to_html_italic
            new_child[2] = iter[2]
            new_child[3] = row[0]+"@@@"+row[3].to_s # Magouille magouille...
        else
            new_child[0] = row[0]
            new_child[1] = row[1].to_html
            new_child[2] = iter[2]
            new_child[3] = row[1]
        end
        if model.iter_depth(new_child) < iter[2].max_level
            # The italic tag is hardcoded because to_hml has already been called and it sucks
            # when called twice on the same string
            new_child[1] = "<i>"+new_child[1]+"</i>" #.to_html_italic
            iter[2].append_fake_child(model, new_child)
        end
    end

    # Load children of iter. If it has childen and first child ref is not -10 the children
    # are already loaded, so do nothing except if force_reload is set to true.
    # If first child ref is -10, it's a fake entry so load the true children
    def load_sub_tree(iter, force_reload = false)

        return if iter.first_child && iter.first_child[0] != GenRowProp::FAKE_ID && !force_reload

        # Trace.debug("*** load new sub tree ***")
        # Making the first column the sort column greatly speeds up things AND makes sure that the
        # fake item is first in the store.
        model.set_sort_column_id(0)

        # Remove all children EXCEPT the first one, it's a gtk treeview requirement!!!
        # If not force_reload, we have just one child, the fake entry, so don't remove it now
        if force_reload
            model.remove(iter.nth_child(1)) while iter.nth_child(1)
            iter[1] = iter[1].gsub(/ - .*$/, "") # Remove the number of entries since it's re-set later
        end

        sql = iter[2].select_for_level(model.iter_depth(iter), iter, @mc, model)

        DBIntf.execute(sql) { |row| map_sub_row_to_entry(row, iter) } unless sql.empty?

        # Perform any post selection required action. By default, removes the first fake child
        iter[2].post_select(model, iter, @mc)

        # Called before the set sort column, so it's sorted by ref, not by name!
        iter[1] = iter[1]+" - (#{iter.n_children})" if iter.first_child[0] != GenRowProp::SELECT_RECORDS

        model.set_sort_column_id(3, Gtk::SORT_ASCENDING)
    end

    def on_row_expanded(widget, iter, path)
        load_sub_tree(iter)
    end

    def on_selection_changed(widget)
        @tvs = selection.selected
        return if @tvs.nil?
        # Trace.debug("artists selection changed".cyan)
        if @tvs.nil? || model.iter_depth(@tvs) < @tvs[2].max_level
            @artlnk.reset
        else
            @artlnk.set_artist_ref(@tvs[ATV_REF])
        end
        @artlnk.to_widgets
        @artlnk.valid_artist_ref? ? @mc.artist_changed : @mc.invalidate_tabs
    end

    # This method is called via the mastercontroller to get the current filter for
    # the records browser.
    def sub_filter
        if @tvs.nil? || @tvs[2].where_fields.empty? || model.iter_depth(@tvs) < @tvs[2].max_level
            return ""
        else
            return @tvs[2].sub_filter(@tvs)
        end
    end

    def on_art_popup_add
        @artlnk.artist.add_new
        load_entries.position_to(@artlnk.artist.rartist)
    end

    def on_art_popup_del
        model.remove(@tvs) if GtkUtils.delete_artist(@tvs[ATV_REF]) == 0 if !@tvs.nil? && GtkUtils.get_response("Sure to delete this artist?") == Gtk::Dialog::RESPONSE_OK
    end

    def on_art_popup_edit
        set_cursor(@tvs.path, columns[ATV_NAME], true) if @tvs
    end

    def on_artist_edited(widget, path, new_text)
        # TODO: should retag and move all audio files!
        if @tvs[ATV_NAME] != new_text
            @tvs[ATV_NAME] = new_text
            @artlnk.artist.sname = new_text
            @artlnk.artist.sql_update
        end
    end

    def update_segment_artist(rartist)
        @seg_art.set_artist_ref(rartist).to_widgets
    end

    def is_on_compile?
        return false if @tvs.nil? || model.iter_depth(@tvs) < @tvs[2].max_level
        return @tvs[0] == 0
    end

    def is_on_never_played?
        return @tvs.nil? ? false : @tvs[2].ref == 7
    end

    def never_played_iter
        iter = model.iter_first
        iter.next! while iter[2].ref != 7
        return !iter || iter.first_child[0] == GenRowProp::FAKE_ID ? nil : iter
    end

    def remove_artist(rartist)
        iter = never_played_iter
        return unless iter
        sub_iter = iter.first_child
        sub_iter.next! while sub_iter[0] != rartist
        if sub_iter[0] == rartist
            model.remove(sub_iter)
            iter[1] = iter[1].gsub(/\ -\ .*$/, "")
            iter[1] = iter[1]+" - (#{iter.n_children})"
        end
    end

    def update_never_played(rrecord, rsegment)
        return unless never_played_iter # Sub tree not loaded, nothing to do

        # If view compile, it's possible to play the last track from an artist that has full disks and
        # thus appears in both compilations and artists list.
        if @mc.view_compile?
            # Check if we can remove compilations or the artist from the list
            rartist = is_on_compile? ? 0 : DBClass::Record.new.ref_load(rrecord).rartist
            sql = "SELECT COUNT(tracks.rtrack) FROM tracks " \
                    "INNER JOIN records ON records.rrecord=tracks.rrecord " \
                    "WHERE records.rartist=#{rartist}"
        else
            # Get artist from segment, we may be on a compile only artist
            rartist = DBClass::Segment.new.ref_load(rsegment).rartist
            sql = "SELECT COUNT(tracks.rtrack) FROM tracks " \
                    "INNER JOIN segments ON segments.rsegment=tracks.rsegment " \
                    "WHERE segments.rartist=#{rartist}"
        end
        sql += " AND tracks.iplayed=0;"

p sql
        remove_artist(rartist) if DBIntf.get_first_value(sql) == 0
    end

    def show_artists_infos
        # TODO: the select on distinct playtime is or may be wrong if two rec/seg have the same length...
        recs_infos = DBIntf.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(records.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN tracks ON tracks.rrecord=records.rrecord
               WHERE rartist=#{@tvs[0]};})
        comp_infos = DBIntf.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(segments.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN segments ON segments.rrecord=records.rrecord
               INNER JOIN tracks ON tracks.rsegment=segments.rsegment
               WHERE segments.rartist=#{@tvs[0]} AND records.rartist=0;})

        GtkUI.load_window(GtkIDs::DLG_ART_INFOS)

        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_COUNT].text = recs_infos[0].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_TRKS].text  = recs_infos[2].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_PT].text    = recs_infos[1].to_i.to_day_length

        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_COUNT].text = comp_infos[0].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_TRKS].text  = comp_infos[2].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_PT].text    = comp_infos[1].to_i.to_day_length

        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_COUNT].text = (recs_infos[0]+comp_infos[0]).to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_TRKS].text  = (recs_infos[2]+comp_infos[2]).to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_PT].text    = (recs_infos[1].to_i+comp_infos[1].to_i).to_day_length

        GtkUI[GtkIDs::DLG_ART_INFOS].show.run
        GtkUI[GtkIDs::DLG_ART_INFOS].destroy
    end

end
