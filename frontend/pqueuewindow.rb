
class PQueueWindow < TopWindow

    PQExtra = Struct.new(:internal_ref, :rtrack, :rrecord, :ptime, :fname, :irecsymlink)

    def initialize(mc)
        super(mc, UIConsts::PQUEUE_WINDOW)

        @mc.glade[UIConsts::PM_PQ_REMOVE].signal_connect(:activate)     { |widget| do_del(widget, false) }
        @mc.glade[UIConsts::PM_PQ_RMFROMHERE].signal_connect(:activate) { |widget| do_del(widget, true) }
        @mc.glade[UIConsts::PM_PQ_CLEAR].signal_connect(:activate)      { @plq.clear; update_status; @tvpq.columns_autosize }
        @mc.glade[UIConsts::PM_PQ_SHOWINBROWSER].signal_connect(:activate) {
            @mc.select_track(@tvpq.selection.selected[4].rtrack) if @tvpq.selection.selected
        }
        @mc.glade[UIConsts::PM_PQ_SHUFFLE].signal_connect(:activate)    { shuffle }

        srenderer = Gtk::CellRendererText.new()
        @tvpq = @mc.glade[UIConsts::TV_PQUEUE]
        # Displayed: Seq, cover, title, length -- Hidden: rtrack, rrecord, track length, true file name
        #@plq = Gtk::ListStore.new(Integer, Gdk::Pixbuf, String, String, Integer, Integer, Integer, String)
        @plq = Gtk::ListStore.new(Integer, Gdk::Pixbuf, String, String, Class)

        pix = Gtk::CellRendererPixbuf.new
        pixcol = Gtk::TreeViewColumn.new("Cover")
        pixcol.pack_start(pix, false)
        pixcol.set_cell_data_func(pix) { |column, cell, model, iter| cell.pixbuf = iter.get_value(1) }

        trk_renderer = Gtk::CellRendererText.new
        trk_column = Gtk::TreeViewColumn.new("Track", trk_renderer)
        trk_column.set_cell_data_func(trk_renderer) { |col, renderer, model, iter| renderer.markup = iter[2] }

        @tvpq.append_column(Gtk::TreeViewColumn.new("Seq.", srenderer, :text => 0))
        @tvpq.append_column(pixcol)
        @tvpq.append_column(trk_column)
        @tvpq.append_column(Gtk::TreeViewColumn.new("Play time", srenderer, :text => 3))
        @tvpq.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event) }
        @tvpq.signal_connect(:drag_end) { |widget, context| i = 0; @plq.each { |model, path, iter| i += 1; iter[0] = i } }

        @tvpq.columns[2].resizable = true

        @tvpq.model = @plq
        @tvpq.reorderable = false #true

        # L'ordre indique la preference quand y'a plusieurs choix
        dragtable = [ ["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700], #DragType::BROWSER_SELECTION],
                      ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105], #DragType::URI_LIST],
                      ["text/plain", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @sw = @mc.glade[UIConsts::SCROLLEDWINDOW_PQUEUE]
        Gtk::Drag::dest_set(@sw, Gtk::Drag::DEST_DEFAULT_ALL, dragtable, Gdk::DragContext::ACTION_COPY)
        @sw.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_drag_received(widget, context, x, y, data, info, time) }

        @tvpq.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [["brower-selection", Gtk::Drag::TargetFlags::SAME_APP, 700]], Gdk::DragContext::ACTION_COPY)
        @tvpq.signal_connect(:drag_data_get) { |widget, drag_context, selection_data, info, time|
            tracks = "pqueue"
            @tvpq.selection.selected_each { |model, path, iter|
                tracks += ":"+iter[4].rtrack.to_s
            }
            selection_data.set(Gdk::Selection::TYPE_STRING, tracks)
        }

        @play_time = 0
        @ntracks = 0
        @internal_ref = 0
    end

    def do_del(widget, rm_next)
        if widget
            return if @tvpq.selection.selected.nil?
            item = @tvpq.selection.selected.path.to_s
        else
            item = "0"
        end
        if rm_next
            while iter = @plq.get_iter(item)
                @plq.remove(iter)
            end
        else
            @plq.remove(@plq.get_iter(item))
            @plq.each { |model, path, iter| iter[0] = path.to_s.to_i+1 }
        end
        update_status
    end

    def shuffle
        order = []
        @plq.each { |model, path, iter| order << path.to_s.to_i }
        return if order.size < 2
        @plq.reorder(order.shuffle!)
        @plq.each { |model, path, iter| iter[0] = path.to_s.to_i+1 }
    end

    def show_popup(widget, event)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            has_sel = !@tvpq.selection.selected.nil?
            @mc.glade[UIConsts::PM_PQ_REMOVE].sensitive = has_sel
            @mc.glade[UIConsts::PM_PQ_RMFROMHERE].sensitive = has_sel
            @mc.glade[UIConsts::PM_PQ_SHOWINBROWSER].sensitive = has_sel
            @mc.glade[UIConsts::PM_PQ].popup(nil, nil, event.button, event.time)
        end
    end

    def get_title_and_length(fname)
        tags = TagLib::File.new(fname)
        title = (tags.track.to_s+". "+tags.title).to_html_bold+"\n"+
                "by "+tags.artist.to_html_italic+"\n"+
                "from "+tags.album.to_html_italic
        length = tags.length*1000
        tags.close
        return [title, length]
    end

    def on_drag_received(widget, context, x, y, data, info, time)
#p info
#   p *data
#   p data.type
#p data.text
#   p data.selection
#   p data.selection.name
#   p data.uris
        case info
            when 700 #DragType::BROWSER_SELECTION
                is_reordering = false
                data.text.split(":").each_with_index { |track, i|
                    if i == 0
                        is_reordering = track == "pqueue"
                    elsif is_reordering
                        itr = nil
                        @plq.each { |model, path, iter| if iter[4].rtrack == track.to_i then itr = iter; break end }
                        if itr
                            r = @tvpq.get_dest_row(x, y)
                            if r.nil?
                                iter = @plq.append
                            else
                                pos = r[0].to_s.to_i
                                pos += 1 if r[1] == Gtk::TreeView::DROP_AFTER || r[1] == Gtk::TreeView::DROP_INTO_OR_AFTER
                                iter = @plq.insert(pos)
                            end
                            @plq.n_columns.times { |i| iter[i] = itr[i] }
                            @plq.remove(itr)
                        end
                    else
                        enqueue(track.to_i)
                    end
                }

            when 105 #DragType::URI_LIST
                data.uris.each { |uri|
                    @internal_ref += 1
                    iter = @plq.append
                    extra = PQExtra.new(@internal_ref, 0, 0, 0, URI::unescape(uri).sub(/^file:\/\//, ""), 0)

                    iter[0] = iter.path.to_s.to_i+1
                    iter[1] = IconsMgr::instance.get_cover(0, 0, 0, 64)
                    iter[2], extra.ptime = get_title_and_length(extra.fname)
                    iter[3] = (extra.ptime/1000).to_sec_length
                    iter[4] = extra
                }
        end
        Gtk::Drag.finish(context, true, false, Time.now.to_i) #,time)
        update_status
        return true
    end

    def enqueue(rtrack)
        track_infos = TrackInfos.new.get_track_infos(rtrack)
        fname = Utils::search_and_get_audio_file(self, @mc.tasks, track_infos)
        unless fname.empty?
            @internal_ref += 1
            iter = @plq.append

            iter[0] = iter.path.to_s.to_i+1
            iter[1] = IconsMgr::instance.get_cover(track_infos.record.rrecord, track_infos.track.rtrack,
                                                   track_infos.record.irecsymlink, 64)
            iter[2] = UIUtils::html_track_title(track_infos, @mc.show_segment_title?)
            iter[3] = (track_infos.track.iplaytime/1000).to_sec_length
            iter[4] = PQExtra.new(@internal_ref, track_infos.track.rtrack, track_infos.record.rrecord,
                                  track_infos.track.iplaytime, fname, track_infos.record.irecsymlink)

            update_status
        end
    end

    def dwl_file_name_notification(rtrack, file_name)
        @plq.each { |model, path, iter|
            if iter[4].rtrack == rtrack
                iter[4].fname = file_name
                @mc.update_track_icon(rtrack)
                break
            end
        }
    end

    def update_status
        @play_time = @ntracks = 0
        @plq.each { |model, path, iter| @ntracks += 1; @play_time += iter[4].ptime }
        update_tracks_label
        update_ptime_label(@play_time)
    end

    def update_tracks_label
        @mc.glade[UIConsts::PQ_LBL_TRACKS].text = @ntracks == 0 ?  "No track" : "#{@ntracks} #{"track".check_plural(@ntracks)}"
    end

    def update_ptime_label(ptime)
        @mc.glade[UIConsts::PQ_LBL_PTIME].text = @ntracks == 0 ? "00:00:00" : ptime.to_hr_length
    end

    def update_eta_label(ptime)
        @mc.glade[UIConsts::PQ_LBL_ETA].text = @ntracks == 0 ? "D.O.A." : Time.at(Time.now.to_i+ptime/1000).strftime("%a %d, %H:%M")
    end

    def timer_notification(ms_time)
        if ms_time == -1
            update_status
            @mc.glade[UIConsts::PQ_LBL_ETA].text = "D.O.A."
        else
            update_ptime_label(@play_time-ms_time)
            update_eta_label(@play_time-ms_time)
        end
    end

    def notify_played(player_data)
        curr_trk = nil
        @plq.each { |model, path, iter| if iter[4].internal_ref == player_data.internal_ref then curr_trk = iter; break; end }
        if curr_trk
            @plq.remove(curr_trk)
            @plq.each { |model, path, iter| iter[0] = path.to_s.to_i+1 }
            @tvpq.columns_autosize
            update_status
        end
    end

    def reset_player_track
        # Nothing to do... but have to respond to the message
    end

    def get_next_track
        entry = player_data = nil
        @plq.each { |model, path, iter| unless iter[4].fname == Utils::DOWNLOADING then entry = iter; break; end }
        if entry
            player_data = PlayerData.new(self, entry[4].internal_ref, entry[4].fname,
                                         entry[4].rtrack, entry[4].rrecord, entry[4].irecsymlink)
        else
            @mc.glade[UIConsts::PQ_LBL_ETA].text = "D.O.A."
        end
        return player_data
    end

    def has_more_tracks(is_next)
        return is_next ? !@plq.get_iter("1").nil? : false
    end

end
