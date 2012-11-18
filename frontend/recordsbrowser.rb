

class RecordsBrowser < GenericBrowser

    RTV_REF     = 0
    RTV_TITLE   = 1
    RTV_PTIME   = 2
    RTV_RS_REF  = 3

#     REC_ROW_RSEG    = 0
#     REC_ROW_TITLE   = 1
#     REC_ROW_PTIME   = 2
#     REC_ROW_STITLE  = 3
#     REC_ROW_REF     = 4
#
#     SEG_ROW_REF     = 0
#     SEG_ROW_TITLE   = 1
#     SEG_ROW_PTIME   = 2
#     SEG_ROW_ANAME   = 3
#     SEG_ROW_RTITLE  = 4
#     SEG_ROW_RISSEG  = 5

    attr_reader :record, :segment

    SegQueryStruct = Struct.new(:seg_ref, :trks_ptime, :art_name)

    class SegInfos

        attr_accessor :query, :entry

        def initialize
            @query = SegQueryStruct.new
            @entry = SegmentDBClass.new
        end

        def store_query(row)
            row.each_with_index { |data, i| @query[i] = data }
            @entry.ref_load(@query.seg_ref)
            return self
        end

        def to_tv_iter(mc, iter)
            record = iter.parent[RTV_RS_REF] # Get record infos from parent
            iter[RTV_REF] = @entry.rsegment
            # If viewing compilation and disc not segmented, display artist's name rather than segment title
            if mc.is_on_compilations? && !record.entry.segmented? # not segmented
                iter[RTV_TITLE] = @query.art_name
            else
                iter[RTV_TITLE] = @entry.stitle.empty? ? record.entry.stitle : @entry.stitle
            end
            iter[RTV_PTIME]  = @query.trks_ptime.to_ms_length
            iter[RTV_RS_REF] = self
            return self
        end
    end


    RecQueryStruct = Struct.new(:seg_ref, :trks_ptime, :seg_rrecord)

    class RecInfos

        attr_accessor :query, :entry, :segs, :rseg, :pixk

        def initialize
            @query = RecQueryStruct.new
            @entry = RecordDBClass.new
            @rseg  = SegmentDBClass.new
            @segs  = []
            @pixk  = "" # Key for record pix map
        end

        def store_query(row)
            row.each_with_index { |data, i| @query[i] = data }
            @entry.ref_load(@query.seg_rrecord)
            @rseg.ref_load(@query.seg_ref)
            return self
        end

        def add_segment(row)
            @segs << SegInfos.new.store_query(row)
        end

        def to_tv_iter(iter)
            iter[RTV_REF]    = @entry.rrecord
            iter[RTV_TITLE]  = @entry.stitle
            iter[RTV_PTIME]  = @query.trks_ptime.to_ms_length
            iter[RTV_RS_REF] = self
            return self
        end
    end


    def initialize(mc)
        super(mc, mc.glade[UIConsts::RECORDS_TREEVIEW])
        @record = RecordUI.new(@mc.glade)
        @segment = SegmentUI.new(@mc.glade)
        @rs = [] # Records store
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

        @tv.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tv.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            selection_data.set(Gdk::Selection::TYPE_STRING, @mc.get_drag_tracks)
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
        @mc.glade[UIConsts::REC_POPUP_SEGORDER].signal_connect(:activate) { Utils::assign_track_seg_order(@record.rrecord) }
        @mc.glade[UIConsts::REC_POPUP_PHISTORY].signal_connect(:activate) {
            PlayHistoryDialog.new.show_record(@record.rrecord)
        }

        return super
    end

    # Generate required sql to load all records or a specific record (rrecord != 1) for the current artist
    # accounting for applied filter
    def generate_rec_sql(rrecord = -1)
#         sql = "SELECT segments.rsegment, records.stitle, SUM(tracks.iplaytime), segments.stitle, segments.rrecord FROM tracks " \
#         sql = "SELECT segments.rsegment, records.rartist, SUM(tracks.iplaytime), segments.rartist, segments.rrecord FROM tracks " \
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

    # Fills record tv entry with an sql result row
#     def map_rec_row_to_entry(row, iter)
#         iter[RTV_REF]    = row.table.rrecord
#         iter[RTV_TITLE]  = row.table.stitle
#         iter[RTV_PTIME]  = row.query.trks_ptime.to_ms_length
#         iter[RTV_RS_REF] = row #.query.seg_ref
#
# #         iter[RTV_REF]    = row[REC_ROW_REF]
# #         iter[RTV_TITLE]  = row[REC_ROW_TITLE]
# #         iter[RTV_PTIME]  = row[REC_ROW_PTIME].to_ms_length
# #         iter[RTV_RS_REF] = row[REC_ROW_RSEG]
#     end

    # Generate required sql to load all segments or a specific segment (rsegment != 1) of the given record
    # accounting for applied filter
    def generate_seg_sql(rrecord, rsegment = -1)
#         sql = "SELECT segments.rsegment, segments.stitle, SUM(tracks.iplaytime), artists.sname, " \
#                      "records.stitle, records.iissegmented FROM tracks "\
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

    # Fills segment tv entry with an sql result row
#     def map_seg_row_to_entry(row, iter)
#         record = iter.parent[RTV_RS_REF] # Get record infos from parent
#         iter[RTV_REF] = row.table.rsegment
#         # If viewing compilation and disc not segmented, display artist's name rather than segment title
#         if record.table.compile? && record.table.segmented? # not segmented
#             iter[RTV_TITLE] = row.table.stitle.empty? ? record.table.stitle : row.table.stitle
#         else
#             iter[RTV_TITLE] = row.query.art_name
#         end
#         iter[RTV_PTIME]  = row.query.trks_ptime.to_ms_length
#         iter[RTV_RS_REF] = row #iter.parent[RTV_REF]
#
# #         iter[RTV_REF] = row[SEG_ROW_REF]
# #         # If viewing compilation and disc not segmented, display artist's name rather than segment title
# #         if @mc.artist.compile? && row[SEG_ROW_RISSEG] == 0 # not segmented
# #             iter[RTV_TITLE] = row[SEG_ROW_ANAME]
# #         else
# #             iter[RTV_TITLE] = row[SEG_ROW_TITLE].empty? ? row[SEG_ROW_RTITLE] : row[SEG_ROW_TITLE]
# #         end
# #         iter[RTV_PTIME]  = row[SEG_ROW_PTIME].to_ms_length
# #         iter[RTV_RS_REF] = iter.parent[RTV_REF]
#     end

    # Fills the record tv with all entries matching current artist and filter
    def load_entries
        @tv.model.clear
        @rs.clear

        DBIntf::connection.execute(generate_rec_sql) do |row|
            iter = @tv.model.append(nil)
            @rs << RecInfos.new.store_query(row).to_tv_iter(iter)

#             iter = @tv.model.append(nil)
#             map_rec_row_to_entry(@rs.last, iter)
#             map_rec_row_to_entry(row, iter)

            # Add a fake entry to have the arrow indicator
            @tv.model.append(iter)
        end
        @tv.columns_autosize

        return self
    end

    def load_rec_and_seg(iter)
        if iter.nil?
            @record.reset
            @segment.reset
        else
            if iter.parent
                @record.clone_dbs(iter.parent[RTV_RS_REF].entry)
                @segment.clone_dbs(iter[RTV_RS_REF].entry)
#                 @record.ref_load(iter.parent[RTV_REF])
#                 @segment.ref_load(iter[RTV_REF])
            else
                @record.clone_dbs(iter[RTV_RS_REF].entry)
                @segment.clone_dbs(iter[RTV_RS_REF].rseg)
                iter[RTV_RS_REF].pixk = IconsMgr::instance.get_cover_key(@record.rrecord, 0, @record.irecsymlink, 128) if iter[RTV_RS_REF].pixk.empty?
                @record.pixk = iter[RTV_RS_REF].pixk
#                 @segment.ref_load(iter[RTV_RS_REF].query.seg_ref)
#                 @record.ref_load(iter[RTV_REF])
#                 @segment.ref_load(iter[RTV_RS_REF].query.seg_ref)
            end
        end
    end

    def load_entries_select_first
        load_entries
        @tv.selection.select_iter(@tv.model.iter_first) if @tv.model.iter_first
puts "@@@ select first @@@"
        return self
    end

    def on_selection_changed(widget)
        # @tv.selection.selected == nil probably means the previous selection is deselected...
        return if @tv.selection.selected.nil?
puts "+++ record selection changed +++"
        load_rec_and_seg(@tv.selection.selected)

        if @record.valid?
            # We must force display of record widgets for the image because if a segment
            # is selected from another record, the image is not refreshed
#             @record.to_widgets_with_cover
            # Redraw segment only if on a segment or the infos string will overwrite the record infos
            if @tv.selection.selected.parent
                @segment.to_widgets
                # Change artist infos if we're browsing a compile subtree
                @mc.change_segment_artist(@segment.rartist) if @mc.artist.compile?
            else
                @record.to_widgets
            end
        end
        @mc.record_changed #if @record.valid?
    end

    def load_segment(rsegment, update_infos = false)
        @segment.ref_load(rsegment)
        @segment.to_widgets if update_infos
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

#     def update_entry(object)
#         ref = object.row_ref
#         if row_visible?(ref)
#             sql = object.kind_of?(RecordDBClass) ? generate_rec_sql(ref) : generate_seg_sql(@record.rrecord, ref)
#             iter = position_to(ref)
#             row = DBIntf::connection.get_first_row(sql)
#             object.kind_of?(RecordDBClass) ? map_rec_row_to_entry(row, iter) : map_seg_row_to_entry(row, iter)
#         end
#     end

#     def update_tv_entry(object)
#         return unless row_visible?(object.dbs[0])
#         ref = object.dbs[0]
#         curr_iter = @tv.selection.selected
#         iter = find_ref(ref)
#         sql = object.kind_of?(RecordDBClass) ? generate_rec_sql(ref) : generate_seg_sql(object.rrecord, ref)
#         iter = position_to(ref) if !curr_iter && curr_iter != iter
#         row = DBIntf::connection.get_first_row(sql)
#         if row
#             object.kind_of?(RecordDBClass) ? map_rec_row_to_entry(row, iter) : map_seg_row_to_entry(row, iter)
#         else
#             @tv.model.remove(iter)
#         end
#     end

#     def update_from_gui(object)
#         object.from_widgets.sql_update
#         update_entry(object)
#     end

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
        @rs.clear
        @record.reset.to_widgets
        @segment.reset.to_widgets
    end

    def is_on_record
        return true if @tv.selection.selected.nil?
        return @tv.selection.selected.parent.nil?
        #return @tv.model.get_iter(@tv.cursor[RTV_REF]).parent.nil?
    end

#     def edit_record
#         rec = RecordEditor.new(@record.rrecord).run if @record.valid?
#         if (rec)
#             update_tv_entry(@record.ref_load(rec.rrecord).to_widgets)
#         end
#     end
#
#     def edit_segment
#         seg = SegmentEditor.new(@segment.rsegment).run if @segment.valid?
#         if (seg)
#             @segment.ref_load(seg.rsegment)
#             update_tv_entry(@segment)
#             @segment.to_widgets
#             #select_segment(@segment.rsegment)
#         end
#     end

    # Fills all children of a record (its segments)
    def on_row_expanded(widget, iter, path)
        fchild = remove_children_but_first(iter)
        DBIntf.connection.execute(generate_seg_sql(iter[RTV_REF])) { |row|
            iter[RTV_RS_REF].add_segment(row)
#             map_seg_row_to_entry(row, @tv.model.append(iter))
#             map_seg_row_to_entry(iter[RTV_RS_REF].segs.last, @tv.model.append(iter))
            iter[RTV_RS_REF].segs.last.to_tv_iter(@mc, @tv.model.append(iter))
        }
        @tv.model.remove(fchild) if fchild
    end

    def update_infos_widgets
        return unless @tv.selection.selected

        if @tv.selection.selected.parent
            @record.disp_cover
            @segment.to_widgets
        else
            @record.to_widgets_with_cover
        end
    end

    def on_rec_edit
        @tv.selection.selected.parent ? DBEditor.new(@mc, @segment).run : DBEditor.new(@mc, @record).run
        @tv.selection.selected[RTV_RS_REF].entry.sql_load # Won't work if pk changed in the editor
        load_rec_and_seg(@tv.selection.selected)
        update_infos_widgets
    end

    def on_rec_add
        @record.add_new(@mc.artist.rartist)
        @segment.add_new(@mc.artist.rartist, @record.rrecord)
        TrackDBClass.new.add_new(@record.rrecord, @segment.rsegment)
        load_entries.position_to(@record.rrecord, 0)
        @mc.record_changed
    end

    def on_seg_add
        @segment.add_new(@mc.artist.rartist, @record.rrecord)
        TrackDBClass.new.add_new(@record.rrecord, @segment.rsegment)
        #rsegment = @segment.rsegment
        load_entries.position_to(@record.rrecord, @segment.rsegment)
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
        DBUtils::log_exec("UPDATE segments SET stitle=#{@record.stitle.to_sql} WHERE rrecord=#{@record.rrecord}")
    end

    def on_tag_dir
        default_dir = case @mc.get_track_status(1)
            when TracksBrowser::TRK_NOT_FOUND,
                 TracksBrowser::TRK_ON_SERVER then Cfg::instance.rip_dir
            when TracksBrowser::TRK_FOUND,
                 TracksBrowser::TRK_MISPLACED then @mc.get_track_infos(1).get_full_dir
        end
        dir = UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER, default_dir)
        unless dir.empty?
            expected, found = Utils::tag_and_move_dir(dir, @record.rrecord) { Gtk.main_iteration while Gtk.events_pending? }
            if expected != found
                UIUtils::show_message("File count mismatch (#{found} found, #{expected} expected).", Gtk::MessageDialog::ERROR)
#             elsif dir.match(/\/rip\//)
            elsif dir.match(Cfg::instance.rip_dir)
                # Set the ripped date only if processing files from my own rip directory...
                DBUtils::client_sql("UPDATE records SET idateripped=#{Time::now.to_i} WHERE rrecord=#{@record.rrecord};")
            end
        end
    end

end
