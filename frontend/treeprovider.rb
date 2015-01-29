
module TreeProvider

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

    FAKE_ID = -10

    SELECT_ARTISTS = -1
    SELECT_RECORDS = -2

    class Generic

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
    class Artists < Generic
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
    class Genres < Generic
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
    class Labels < Generic
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
    class Origins < Generic
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
    class Tags < Generic
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
    class Ripped < Generic
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
                    # child[1] += CGI::escapeHTML(row[row[1] == 0 ? 4 : 2])
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
    class NeverPlayed < Generic
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
    class Ratings < Generic
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
    class PlayTime < Generic

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
            return " #@where_fields >  #{iter.parent.parent[0]-TINC} AND \
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
    class Records < Generic
        def select_for_level(level, iter, mc, model)
            if level == 0
                sql = %Q{SELECT records.stitle, artists.rartist, artists.sname, records.rrecord FROM records
                        INNER JOIN artists ON records.rartist = artists.rartist;}
                        # ORDER BY LOWER(records.stitle);}
                DBIntf.execute(sql) { |row|
                    child = model.append(iter)
                    child[0] = row[1]
                    # child[1] = '<span color="green">'+CGI::escapeHTML(row[0])+"</span>\n<i>"+CGI::escapeHTML(row[2])+"</i>"
                    # child[1] = "<b>"+CGI::escapeHTML(row[0])+"</b>\nby <i>"+CGI::escapeHTML(row[2])+"</i>"
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
end
