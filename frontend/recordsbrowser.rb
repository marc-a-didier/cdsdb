

class RecordsBrowser < GenericBrowser

    RTV_REF   = 0
    RTV_TITLE = 1
    RTV_PTIME = 2
    RTV_DBLNK = 3

    attr_reader :reclnk


    def initialize(mc)
        super(mc, mc.glade[UIConsts::RECORDS_TREEVIEW])
        @reclnk = RecordUI.new # Lost instance but setting to nil is not possible
    end

    def setup
        renderer = Gtk::CellRendererText.new

        ["Ref.", "Title", "Play time"].each_with_index { |name, i| @tv.append_column(Gtk::TreeViewColumn.new(name, renderer, :text => i)) }
        @tv.columns[RTV_TITLE].resizable = @tv.columns[RTV_TITLE].sort_indicator = @tv.columns[RTV_TITLE].clickable = true
        @tv.columns[RTV_TITLE].signal_connect(:clicked) { change_sort_order(RTV_TITLE) } #{ load_entries } }

        # Last column is the record reference, not shown in the tree view.
        @tv.model = Gtk::TreeStore.new(Integer, String, String, Class)
        #!! Si on est mode Gtk::SELECTION_BROWSE, on recoit un selection_changed meme si on clique sur la meme entree!!
        @tv.selection.mode = Gtk::SELECTION_SINGLE
        #@tv.selection.mode = Gtk::SELECTION_BROWSE

        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            selection_data.set(Gdk::Selection::TYPE_STRING, "records:message:get_tracks_list")
        }
        @tv.selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        @tv.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, UIConsts::REC_POPUP_MENU) }

        @tv.signal_connect(:row_expanded) { |widget, iter, path| on_row_expanded(widget, iter, path) }

        @mc.glade[UIConsts::REC_POPUP_EDIT].signal_connect(:activate)     { on_rec_edit }
        @mc.glade[UIConsts::REC_POPUP_ADD].signal_connect(:activate)      { on_rec_add }
        @mc.glade[UIConsts::REC_POPUP_DEL].signal_connect(:activate)      { on_rec_or_seg_del }
        @mc.glade[UIConsts::REC_POPUP_SEGADD].signal_connect(:activate)   { on_seg_add }
        @mc.glade[UIConsts::REC_POPUP_CPTITLE].signal_connect(:activate)  { on_cp_title_to_segs }
        @mc.glade[UIConsts::REC_POPUP_TAGDIR].signal_connect(:activate)   { on_tag_dir }
        @mc.glade[UIConsts::REC_POPUP_ENQUEUE].signal_connect(:activate)  { @mc.enqueue_record }
        @mc.glade[UIConsts::REC_POPUP_DOWNLOAD].signal_connect(:activate) { @mc.download_tracks }
        @mc.glade[UIConsts::REC_POPUP_SEGORDER].signal_connect(:activate) { Utils::assign_track_seg_order(@reclnk.record.rrecord) }
        @mc.glade[UIConsts::REC_POPUP_PHISTORY].signal_connect(:activate) {
            PlayHistoryDialog.new.show_record(@reclnk.record.rrecord)
        }

        return super
    end

    # Generate required sql to load all records or a specific record (rrecord != 1) for the current artist
    # accounting for applied filter
    def generate_rec_sql(rrecord = -1)
        sql = "SELECT segments.rsegment, SUM(tracks.iplaytime), segments.rrecord FROM tracks " \
                "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                "INNER JOIN records ON records.rrecord=segments.rrecord " \
                "INNER JOIN artists ON artists.rartist=segments.rartist "
        sql += @mc.artist.compile? ? "WHERE records.rartist=" : "WHERE segments.rartist="
        sql += @mc.artist.rartist.to_s
        sql += " AND records.rrecord=#{rrecord}" unless rrecord == -1
        sql += " AND "+@mc.sub_filter unless @mc.sub_filter.empty?
        sql += @mc.main_filter if @mc.sub_filter.empty? # Don't apply 2 filters at once!!!
        sql += @mc.artist.compile? ? " GROUP BY records.rrecord " : " GROUP BY segments.rrecord " # ??? ca change quoi ???
        sql += " ORDER BY LOWER(records.stitle)"
        sql += " DESC" if @tv.columns[RTV_TITLE].sort_order == Gtk::SORT_DESCENDING
        sql += ", segments.rsegment" # End of order by

#p sql
        return sql
    end


    # Generate required sql to load all segments or a specific segment (rsegment != 1) of the given record
    # accounting for applied filter
    def generate_seg_sql(rrecord, rsegment = -1)
        sql = "SELECT segments.rsegment, SUM(tracks.iplaytime), artists.sname FROM tracks " \
                "INNER JOIN segments ON tracks.rsegment=segments.rsegment " \
                "INNER JOIN records ON records.rrecord=tracks.rrecord " \
                "INNER JOIN artists ON segments.rartist=artists.rartist "
        if rsegment == -1
            sql += " WHERE segments.rrecord=#{rrecord}"
            sql += " AND segments.rartist=#{@mc.artist.rartist}" unless @mc.artist.compile?
        else
            sql += " WHERE segments.rsegment=#{rsegment}"
        end
        sql += " AND "+@mc.sub_filter unless @mc.sub_filter.empty?
        sql += @mc.main_filter if @mc.sub_filter.empty? # Don't apply 2 filters at once!!!
        sql += " GROUP BY segments.rsegment ORDER BY segments.iorder;"

        return sql
    end


    # Fills the record tv with all entries matching current artist and filter
    def load_entries
        @tv.model.clear

        DBIntf::connection.execute(generate_rec_sql) do |row|
            iter = @tv.model.append(nil)

            dblink = RecordUI.new.set_record_ref(row[2]).set_segment_ref(row[0])
            iter[RTV_REF]   = dblink.record.rrecord
            iter[RTV_TITLE] = dblink.record.stitle
            iter[RTV_PTIME] = row[1].to_ms_length
            iter[RTV_DBLNK] = dblink

            # Add a fake entry to have the arrow indicator
            @tv.model.append(iter)[RTV_REF] = -1
        end
        @tv.columns_autosize

        return self
    end

    def update_ui_handlers(iter)
        iter.nil? ? @reclnk.reset : @reclnk = iter[RTV_DBLNK]
    end

    def load_entries_select_first
        load_entries
        @tv.selection.select_iter(@tv.model.iter_first) if @tv.model.iter_first
        return self
    end

    def on_selection_changed(widget)
        # @tv.selection.selected == nil probably means the previous selection is deselected...
        return if @tv.selection.selected.nil?
# Trace.log.debug("record selection changed")
        update_ui_handlers(@tv.selection.selected)

        if @reclnk.record.valid?
            # Redraw segment only if on a segment or the infos string will overwrite the record infos
            if @tv.selection.selected.parent
                @reclnk.to_widgets(false)
                # Change artist infos if we're browsing a compile subtree
                @mc.change_segment_artist(@reclnk.segment.rartist) if @mc.artist.compile?
            else
                @reclnk.to_widgets(true)
            end
        end
        @mc.record_changed #if @reclnk.valid?
    end


    # Called from master controller to keep tracks synched
    def load_segment(rsegment, update_infos = false)
        @reclnk.set_segment_ref(rsegment)
        @reclnk.to_widgets(false) if update_infos
    end

    def select_record(rrecord)
        return position_to(rrecord)
    end

    def select_segment_from_record_selection(rsegment)
        iter = @tv.selection.selected
        if iter
            @tv.expand_row(iter.path, false)
            siter = iter.first_child
            while siter && siter[0] != rsegment
                siter.next!
            end
            @tv.set_cursor(siter.path, nil, false) if siter
        end
    end

    def set_selection(rrecord, rsegment)
        iter = position_to(rrecord)
        if iter && rsegment != 0
            @tv.expand_row(iter.path, false)
            siter = iter.first_child
            while siter && siter[0] != rsegment
                siter.next!
            end
            @tv.set_cursor(siter.path, nil, false) if siter
            return siter
        end
        return iter
    end


    # Returns true if we should check if we can remove the artist from the never played sub tree.
    # WARNING: The only case where we're sure that it should not be removed is when there are still tracks,
    #          in this case when row is not nil.
    def update_never_played(rrecord, rsegment)
        return true unless @mc.is_on_never_played?
        iter = find_ref(rrecord)
        return true if iter.nil?

        row = DBIntf::connection.get_first_row(generate_rec_sql(rrecord))
p row
        if row
            map_rec_row_to_entry(row, iter)
        else
            @tv.model.remove(iter)
        end
        @mc.record_changed
        return row.nil?
    end

    def invalidate
        @tv.model.clear
        @reclnk.reset.to_widgets(true) if @reclnk.valid?
    end

    def is_on_record
        return true if @tv.selection.selected.nil?
        return @tv.selection.selected.parent.nil?
    end

    # Fills all children of a record (its segments)
    def on_row_expanded(widget, iter, path)
        # Exit if row has already been loaded, children are already there
        return if iter.first_child && iter.first_child[RTV_REF] != -1

        DBIntf.connection.execute(generate_seg_sql(iter[RTV_REF])) { |row|
            child = @tv.model.append(iter)

            dblink = RecordUI.new.set_segment_ref(row[0])
            dblink.set_record_ref(dblink.segment.rrecord)

            child[RTV_REF] = dblink.segment.rsegment
            # If viewing compilation and disc not segmented, display artist's name rather than segment title
            if @mc.is_on_compilations? && !dblink.record.segmented?
                child[RTV_TITLE] = row[2]
            else
                child[RTV_TITLE] = dblink.segment.stitle.empty? ? child.parent[RTV_TITLE] : dblink.segment.stitle
            end
            child[RTV_PTIME] = row[1].to_ms_length
            child[RTV_DBLNK] = dblink
        }
        @tv.model.remove(iter.first_child)
    end

    def on_rec_edit
        resp = @tv.selection.selected.parent ? DBEditor.new(@mc, @reclnk.segment).run : DBEditor.new(@mc, @reclnk.record).run
        if resp == Gtk::Dialog::RESPONSE_OK
            # Won't work if pk changed in the editor...
            @tv.selection.selected[RTV_DBLNK].reload_segment_cache.reload_record_cache
            # update_ui_handlers(@tv.selection.selected)
            @reclnk.to_widgets(!@tv.selection.selected.parent)
        end
    end

    def on_rec_add
        @reclnk.record.add_new(@mc.artist.rartist)
        @reclnk.segment.add_new(@mc.artist.rartist, @reclnk.record.rrecord)
        TrackDBClass.new.add_new(@reclnk.record.rrecord, @reclnk.segment.rsegment)
        load_entries.position_to(@reclnk.record.rrecord, 0)
        @mc.record_changed
    end

    def on_seg_add
        @segment.add_new(@mc.artist.rartist, @reclnk.rrecord)
        TrackDBClass.new.add_new(@reclnk.rrecord, @segment.rsegment)
        #rsegment = @segment.rsegment
        load_entries.position_to(@reclnk.rrecord, @segment.rsegment)
        #iter = @tv.selection.selected
        #on_row_expanded(self, iter, iter.path)
        #position_to(rsegment)
    end

    def on_rec_or_seg_del
        return if @tv.cursor.nil?
        iter = @tv.model.get_iter(@tv.cursor[RTV_REF])
        txt = iter.parent ? "segment" : "record"
        if UIUtils::get_response("Sure to delete this #{txt}?") == Gtk::Dialog::RESPONSE_OK
            res = iter.parent ? UIUtils::delete_segment(iter[RTV_REF]) : UIUtils::delete_record(iter[RTV_REF])
            @tv.model.remove(iter) if res == 0
        end
    end

    def on_cp_title_to_segs
        DBUtils::log_exec("UPDATE segments SET stitle=#{@reclnk.stitle.to_sql} WHERE rrecord=#{@reclnk.rrecord}")
    end

    def on_tag_dir
        uilink = @mc.get_track_uilink(0)
        return if !uilink || uilink.audio_status == AudioLink::UNKNOWN

        default_dir = uilink.playable? ? uilink.full_dir : Cfg::instance.rip_dir

        dir = UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER, default_dir)
        unless dir.empty?
            expected, found = uilink.tag_and_move_dir(dir) { |param| @mc.audio_link_ok(param) }
            if expected != found
                UIUtils::show_message("File count mismatch (#{found} found, #{expected} expected).", Gtk::MessageDialog::ERROR)
            elsif dir.match(Cfg::instance.rip_dir)
                # Set the ripped date only if processing files from the rip directory.
#                 DBUtils::client_sql("UPDATE records SET idateripped=#{Time::now.to_i} WHERE rrecord=#{@reclnk.record.rrecord};")
                @reclnk.record.idateripped = Time::now.to_i
                @reclnk.record.sql_update
            end
        end
    end

end
