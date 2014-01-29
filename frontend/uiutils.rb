
#
# Extension of Utils class but with UI dependance
#

#
# Interface to Gtk::Builder
#
# @@main is the content of cdsdb.glade in which windows are NEVER deleted but hidden instead.
#
# load(win_id) is used to load the UI definition of the windows from the corresponding file.
# In this case, windows MUST be destroyed or leaks looms in the dark...
#

class GTBld

private
    @@main = nil

public
    def self.main
        #@@main ? @@main : @@main = Gtk::Builder.new.add(CFG.rsrc_dir+"cdsdb.gtb").connect_signals { |handler| method(handler) }
        @@main ? @@main : @@main = Gtk::Builder.new.add("../glade/cdsdb.glade").connect_signals { |handler| method(handler) }
    end

    def self.load(win_id)
        #build = Gtk::Builder.new.add(CFG.rsrc_dir+win_id+".glade").connect_signals { |handler| method(handler) }
        build = Gtk::Builder.new.add("../glade/#{win_id}.glade").connect_signals { |handler| method(handler) }
        return build
    end
end

# A bit of treeview extension...
# class Gtk::TreeView
# 
#     def find_ref(ref, column = 0)
#         model.each { |model, path, iter| return iter if iter[column] == ref }
#         return nil
#     end
# 
# end


class UIUtils

    #
    # Generic methods to deal with the user
    #

    def UIUtils::show_message(msg, msg_type)
        dialog = Gtk::MessageDialog.new(nil, Gtk::Dialog::MODAL, msg_type, Gtk::MessageDialog::BUTTONS_OK, msg)
        dialog.title = "Information"
        dialog.run # {|r| puts "response=%d" % [r]}
        dialog.destroy
    end

    def UIUtils::get_response(msg)
        dialog = Gtk::MessageDialog.new(nil, Gtk::Dialog::MODAL, Gtk::MessageDialog::WARNING,
                                        Gtk::MessageDialog::BUTTONS_OK_CANCEL, msg)
        dialog.title = "Warning"
        response = dialog.run
        dialog.destroy
        return response
    end

    def UIUtils::select_source(action, default_dir = "")
        file = ""
        action == Gtk::FileChooser::ACTION_OPEN ? title = "Select file" : title = "Select directory"
        dialog = Gtk::FileChooserDialog.new(title, nil, action, nil,
                                            [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                            [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
        dialog.current_folder = default_dir.empty? ? CFG.music_dir : default_dir
        file = dialog.filename if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        dialog.destroy
        return file
    end


    #
    # Tree view builder for tags selector
    #

    def UIUtils::setup_tracks_tags_tv(tvt)
        tvt.model = Gtk::ListStore.new(TrueClass, String)

        arenderer = Gtk::CellRendererToggle.new
        arenderer.activatable = true
        arenderer.signal_connect(:toggled) { |w, path|
            iter = tvt.model.get_iter(path)
            iter[0] = !iter[0] if (iter)
        }
        srenderer = Gtk::CellRendererText.new()

        tvt.append_column(Gtk::TreeViewColumn.new("Match", arenderer, :active => 0))
        tvt.append_column(Gtk::TreeViewColumn.new("Tag", srenderer, :text => 1))
        UIConsts::TAGS.each { |tag|
            iter = tvt.model.append
            iter[0] = false
            iter[1] = tag
        }
    end

    def self.get_tags_mask(tvt)
        mask = 0
        i = 1
        tvt.model.each { |model, path, iter| mask |= i if iter[0]; i <<= 1 }
        return mask
    end


    #
    # Pix maps generator for button icons
    #
    def UIUtils::get_btn_icon(fname)
#         return File.exists?(fname) ? Gdk::Pixbuf.new(fname, 22, 22) : Gdk::Pixbuf.new(CFG.icons_dir+"default.svg", 22, 22)
        return File.exists?(fname) ? Gdk::Pixbuf.new(fname, 22, 22) : Gdk::Pixbuf.new(CFG.icons_dir+"default.svg", 22, 22)
    end

    #
    # Builds a track name to be displayed in an html context (lists, player, ...)
    # title is expected to be complete, with track number, title, seg order and seg title if any
    #
    def UIUtils::full_html_track_title(title, artist, record, separator = "\n")
#         return "<b>"+CGI::escapeHTML(title)+"</b>"+separator+
#                 "by <i>"+CGI::escapeHTML(artist)+"</i>"+separator+
#                 "from <i>"+CGI::escapeHTML(record)+"</i>"
        return title.to_html_bold+separator+"by "+artist.to_html_italic+separator+"from "+record.to_html_italic
    end

    # Builds an html track title from a DB track_infos, NOT tags track_infos
    def UIUtils::html_track_title(track_infos, add_segment)
        return UIUtils::full_html_track_title(
                    Utils::make_track_title(track_infos.track.iorder, track_infos.track.stitle,
                                            track_infos.track.isegorder, track_infos.segment.stitle,
                                            add_segment),
                    track_infos.seg_art.sname,
                    track_infos.record.stitle)
    end

    # Builds an html track title from a TAGS track_infos, NOT DB track_infos
    # At this time, only called from the player window for title and tooltip infos
    def UIUtils::tags_html_track_title(track_infos, separator)
        return UIUtils::full_html_track_title(
                    Utils::make_track_title(track_infos.track.iorder, track_infos.title, 0, "", false),
                    track_infos.seg_art.sname,
                    track_infos.record.stitle,
                    separator)
    end


    #
    # Database utilities that may require user intervention
    #

    def UIUtils::import_played_tracks
        return if UIUtils::get_response("OK to import tracks from playedtracks.sql?") != Gtk::Dialog::RESPONSE_OK
        rlogtrack = DBUtils::get_last_id("logtrack")
        IO.foreach(CFG.rsrc_dir+"playedtracks.sql") { |line|
            line = line.chomp
            if line.match(/^INSERT/)
                rlogtrack += 1
                #print "replacing @#{line}@ with "
                line.sub!(/\([0-9]*/, "(#{rlogtrack}")
                #puts line
            end
            DBUtils::log_exec(line)
        }
    end

    def UIUtils::delete_artist(rartist)
        msg = ""
        count = CDSDB.get_first_value("SELECT COUNT(rartist) FROM records WHERE rartist=#{rartist};")
        msg = "Error: #{count} reference(s) still in records table." if count > 0
        count = CDSDB.get_first_value("SELECT COUNT(rartist) FROM segments WHERE rartist=#{rartist};")
        if count > 0
            msg += "\n" if msg.length > 0
            msg += "Error: #{count} reference(s) still in segments table."
        end
        if msg.length > 0
            UIUtils::show_message(msg, Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM artists WHERE rartist=#{rartist};")
            return 0
        end
        return 1
    end

    def UIUtils::delete_segment(rsegment)
        count = CDSDB.get_first_value("SELECT COUNT(rsegment) FROM tracks WHERE rsegment=#{rsegment};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in tracks table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM segments WHERE rsegment=#{rsegment};")
        end
        return count
    end

    def UIUtils::delete_record(rrecord)
        count = CDSDB.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rrecord=#{rrecord};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in segments table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM records WHERE rrecord=#{rrecord};")
        end
        return count
    end

    def UIUtils::delete_track(rtrack)
        count = CDSDB.get_first_value("SELECT COUNT(rpltrack) FROM pltracks WHERE rtrack=#{rtrack};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in play lists.", Gtk::MessageDialog::ERROR)
        else
            row = CDSDB.execute("SELECT rsegment, rrecord FROM tracks WHERE rtrack=#{rtrack}")
            count = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rsegment=#{row[0][0]}")
            del_seg = count == 1 && UIUtils::get_response("This is the last track of its segment. Remove it along?") == Gtk::Dialog::RESPONSE_OK
            count = CDSDB.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{row[0][1]}")
            del_rec = count == 1 && UIUtils::get_response("This is the last track of its record. Remove it along?") == Gtk::Dialog::RESPONSE_OK

            DBUtils::client_sql("DELETE FROM logtracks WHERE rtrack=#{rtrack};")
            DBUtils::client_sql("DELETE FROM tracks WHERE rtrack=#{rtrack};")

            delete_segment(row[0][0]) if del_seg
            delete_record(row[0][1]) if del_rec
        end
        return count
    end

end
