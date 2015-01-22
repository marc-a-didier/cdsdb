

class RecordsBrowser < Gtk::TreeView

    RTV_REF   = 0
    RTV_TITLE = 1
    RTV_PTIME = 2
    RTV_DBLNK = 3

    attr_reader :reclnk


    def initialize
        super
        @reclnk = RecordUI.new # Lost instance but setting to nil is not possible
    end

    def setup(mc)
        @mc = mc
        GtkUI[GtkIDs::RECORDS_TVC].add(self)
        self.visible = true
        self.enable_search = true
        self.search_column = 1

        renderer = Gtk::CellRendererText.new

        ["Ref.", "Title", "Play time"].each_with_index { |name, i| append_column(Gtk::TreeViewColumn.new(name, renderer, :text => i)) }
        columns[RTV_TITLE].resizable = columns[RTV_TITLE].sort_indicator = columns[RTV_TITLE].clickable = true
        columns[RTV_TITLE].signal_connect(:clicked) { change_sort_order(RTV_TITLE) } #{ load_entries } }

        # Last column is the record reference, not shown in the tree view.
        self.model = Gtk::TreeStore.new(Integer, String, String, Class)
        #!! Si on est mode Gtk::SELECTION_BROWSE, on recoit un selection_changed meme si on clique sur la meme entree!!
        selection.mode = Gtk::SELECTION_SINGLE
        #@tv.selection.mode = Gtk::SELECTION_BROWSE

        enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["browser-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            selection_data.set(Gdk::Selection::TYPE_STRING, "records:message:get_tracks_list")
        }
        selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        signal_connect(:button_press_event) { |widget, event| show_popup(widget, event, GtkIDs::REC_POPUP_MENU) }

        signal_connect(:row_expanded) { |widget, iter, path| on_row_expanded(widget, iter, path) }

        GtkUI[GtkIDs::REC_POPUP_EDIT].signal_connect(:activate)     { on_rec_edit }
        GtkUI[GtkIDs::REC_POPUP_ADD].signal_connect(:activate)      { on_rec_add }
        GtkUI[GtkIDs::REC_POPUP_DEL].signal_connect(:activate)      { on_rec_or_seg_del }
        GtkUI[GtkIDs::REC_POPUP_SEGADD].signal_connect(:activate)   { on_seg_add }
        GtkUI[GtkIDs::REC_POPUP_CPTITLE].signal_connect(:activate)  { on_cp_title_to_segs }
        GtkUI[GtkIDs::REC_POPUP_TAGDIR].signal_connect(:activate)   { on_tag_dir }
        GtkUI[GtkIDs::REC_POPUP_ENQUEUE].signal_connect(:activate)  { @mc.enqueue_record }
        GtkUI[GtkIDs::REC_POPUP_DOWNLOAD].signal_connect(:activate) { @mc.download_tracks }
        GtkUI[GtkIDs::REC_POPUP_SEGORDER].signal_connect(:activate) { Utils::assign_track_seg_order(@reclnk.record.rrecord) }
        GtkUI[GtkIDs::REC_POPUP_PHISTORY].signal_connect(:activate) {
            PlayHistoryDialog.new.show_record(@reclnk.record.rrecord)
        }

        GtkUI[GtkIDs::REC_POPUP_GETRPGAIN].signal_connect(:activate) { get_replay_gain }

        return finalize_setup
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
        sql += " DESC" if columns[RTV_TITLE].sort_order == Gtk::SORT_DESCENDING
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
        model.clear

        DBIntf.execute(generate_rec_sql) do |row|
            iter = model.append(nil)

            dblink = RecordUI.new.set_record_ref(row[2]).set_segment_ref(row[0])
            iter[RTV_REF]   = dblink.record.rrecord
            iter[RTV_TITLE] = dblink.record.stitle
            iter[RTV_PTIME] = row[1].to_ms_length
            iter[RTV_DBLNK] = dblink

            # Add a fake entry to have the arrow indicator
            model.append(iter)[RTV_REF] = -1
        end
        columns_autosize

        return self
    end

    def update_ui_handlers(iter)
        iter.nil? ? @reclnk.reset : @reclnk = iter[RTV_DBLNK]
    end

    def load_entries_select_first
        load_entries
        selection.select_iter(model.iter_first) if model.iter_first
        return self
    end

    def on_selection_changed(widget)
        # @tv.selection.selected == nil probably means the previous selection is deselected...
        return if selection.selected.nil?
# TRACE.debug("record selection changed")
        update_ui_handlers(selection.selected)

        if @reclnk.valid_record_ref?
            # Redraw segment only if on a segment or the infos string will overwrite the record infos
            if selection.selected.parent
                @reclnk.to_widgets(false)
                # Change artist infos if we're browsing a compile subtree
                @mc.update_artist_infos(@reclnk.segment.rartist) if @mc.artist.compile?
            else
                @reclnk.to_widgets(true)
            end
        end
        @mc.record_changed #if @reclnk.valid?
    end


    # Called from master controller to keep tracks synched -- Never called, may be removed
    def load_segment(rsegment, update_infos = false)
        @reclnk.set_segment_ref(rsegment)
        @reclnk.to_widgets(false) if update_infos
    end

    # Called via mc when a track is changed in tracks browser to keep segment synched
    def set_segment_from_track(rsegment)
        @reclnk.set_segment_ref(rsegment)
    end

    def select_record(rrecord)
        return position_to(rrecord)
    end

    def select_segment_from_record_selection(rsegment)
        iter = selection.selected
        if iter
            expand_row(iter.path, false)
            siter = iter.first_child
            while siter && siter[0] != rsegment
                siter.next!
            end
            set_cursor(siter.path, nil, false) if siter
        end
    end

    def set_selection(rrecord, rsegment)
        iter = position_to(rrecord)
        if iter && rsegment != 0
            expand_row(iter.path, false)
            siter = iter.first_child
            while siter && siter[0] != rsegment
                siter.next!
            end
            set_cursor(siter.path, nil, false) if siter
            return siter
        end
        return iter
    end


    # Returns true if we should check if we can remove the artist from the never played sub tree.
    # WARNING: The only case where we're sure that it should not be removed is when there are still tracks,
    #          in this case when row is not nil.
    def update_never_played(uilink)
        return true unless @mc.is_on_never_played?
        iter = find_ref(uilink.record.rrecord)
        return true if iter.nil?

        row = DBIntf.get_first_row(generate_rec_sql(uilink.record.rrecord))
p row
        if row
            map_rec_row_to_entry(row, iter)
        else
            model.remove(iter)
        end
        @mc.record_changed
        return row.nil?
    end

#     def update_never_played(rrecord, rsegment)
#         return true unless @mc.is_on_never_played?
#         iter = find_ref(rrecord)
#         return true if iter.nil?
#
#         row = DBIntf.get_first_row(generate_rec_sql(rrecord))
# p row
#         if row
#             map_rec_row_to_entry(row, iter)
#         else
#             model.remove(iter)
#         end
#         @mc.record_changed
#         return row.nil?
#     end

    def invalidate
        model.clear
        @reclnk.reset.to_widgets(true) if @reclnk.valid_record_ref?
    end

    def is_on_record
        return true if selection.selected.nil?
        return selection.selected.parent.nil?
    end

    # Fills all children of a record (its segments)
    def on_row_expanded(widget, iter, path)
        # Exit if row has already been loaded, children are already there
        return if iter.first_child && iter.first_child[RTV_REF] != -1

        DBIntf.execute(generate_seg_sql(iter[RTV_REF])) { |row|
            child = model.append(iter)

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
        model.remove(iter.first_child)
    end

    def on_rec_edit
        rgenre = @reclnk.record.rgenre
        if DBEditor.new(@mc, @reclnk, selection.selected.parent ? DBEditor::SEGMENT_PAGE : DBEditor::RECORD_PAGE).run == Gtk::Dialog::RESPONSE_OK
            # Won't work if pk changed in the editor...
            @reclnk.to_widgets(!selection.selected.parent)
            # If genre changed in editor, reset the audio status to unknown to force reload
            if @reclnk.record.rgenre != rgenre
                @mc.get_tracks_list.each { |dblink| dblink.set_audio_status(Audio::Status::UNKNOWN) }
                @mc.record_changed
            end
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
        return if cursor.nil?
        iter = model.get_iter(cursor[RTV_REF])
        txt = iter.parent ? "segment" : "record"
        if GtkUtils.get_response("Sure to delete this #{txt}?") == Gtk::Dialog::RESPONSE_OK
            res = iter.parent ? GtkUtils.delete_segment(iter[RTV_REF]) : GtkUtils.delete_record(iter[RTV_REF])
            model.remove(iter) if res == 0
        end
    end

    def on_cp_title_to_segs
        DBUtils::log_exec("UPDATE segments SET stitle=#{@reclnk.stitle.to_sql} WHERE rrecord=#{@reclnk.rrecord}")
    end

    def on_tag_dir
        # TODO: Urgence: y'a bug!!! uilink is set to the last track. Replace it with a new instance of AudioLink!!
        uilink = @mc.get_track_uilink(0) #.clone
        return if !uilink || uilink.audio_status == Audio::Status::UNKNOWN

# p uilink.full_dir
        default_dir = uilink.playable? ? uilink.full_dir : CFG.rip_dir

        dir = GtkUtils.select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER, default_dir)
        unless dir.empty?
            expected, found = uilink.tag_and_move_dir(dir) { |param| @mc.audio_link_ok(param) }
            if expected != found
                GtkUtils.show_message("File count mismatch (#{found} found, #{expected} expected).", Gtk::MessageDialog::ERROR)
            elsif dir.match(CFG.rip_dir[0..-2]) # Remove last / if files are not in rip sub dir
                # Set the ripped date only if processing files from the rip directory.
                @reclnk.record.idateripped = Time::now.to_i
                @reclnk.record.sql_update
            end
        end
    end

    def get_replay_gain
        tracks = @mc.get_tracks_list
        tracks.each do |trackui|
            trackui.setup_audio_file if trackui.audio_file.empty?
            unless trackui.playable?
                GtkUtils.show_message("All tracks must be available on disk.",  Gtk::MessageDialog::ERROR)
                return
            end
        end

        Utils.compute_replay_gain(tracks)
    end

end #179-063

