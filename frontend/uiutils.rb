
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
        #@@main ? @@main : @@main = Gtk::Builder.new.add(Cfg::instance.rsrc_dir+"cdsdb.gtb").connect_signals { |handler| method(handler) }
        @@main ? @@main : @@main = Gtk::Builder.new.add("../glade/cdsdb.glade").connect_signals { |handler| method(handler) }
    end

    def self.load(win_id)
        #build = Gtk::Builder.new.add(Cfg::instance.rsrc_dir+win_id+".glade").connect_signals { |handler| method(handler) }
        build = Gtk::Builder.new.add("../glade/#{win_id}.glade").connect_signals { |handler| method(handler) }
        return build
    end
end

# A bit of treeview extension...
class Gtk::TreeView

    def find_ref(ref, column = 0)
        model.each { |model, path, iter| return iter if iter[column] == ref }
        return nil
    end

end

# Extends BasicDataStore to add UI related functions like covers, html titles, etc...

class UIStore < BasicDataStore

#     attr_reader :track, :cover

    def initialize
        super()
        @cover   = CoverMgr.new
    end


    def init_from_tags(file_name)
        load_from_tags(file_name)
        # Should set the cover to default.
        return self
    end


    def cover_file_name
        return @cover.file_name(track.rtrack, track.rrecord, record.irecsymlink)
    end

    def large_track_cover
        return @cover.track_pix(track.rtrack, track.rrecord, record.irecsymlink, IconsMgr::LARGE_SIZE)
    end

    def small_track_cover
        return @cover.track_pix(track.rtrack, track.rrecord, record.irecsymlink, IconsMgr::SMALL_SIZE)
    end

    def large_record_cover
        return @cover.record_pix(record.rrecord, record.irecsymlink, IconsMgr::LARGE_SIZE)
    end

    def small_record_cover
        return @cover.record_pix(record.rrecord, record.irecsymlink, IconsMgr::SMALL_SIZE)
    end

    def cover_key
        return @cover.pix_key
    end


    def get_audio_file(emitter, tasks)
        # Try to find a local file if status is unknown
        setup_audio_file if @audio_status == Utils::FILE_UNKNOWN

        # If status is not found, exit. May be add code to check if on server...
        return @audio_status if @audio_status == Utils::FILE_NOT_FOUND

        # If status is on server, get the remote file. It can only come from the tracks browser.
        # If file is coming from charts, play list or any other, the track won't be downloaded.
        return get_remote_audio_file(emitter, tasks) if @audio_status == Utils::FILE_ON_SERVER
    end

    def get_remote_audio_file(emitter, tasks)
        if Cfg::instance.remote? && Cfg::instance.local_store?
            tasks.new_track_download(emitter, track.stitle, track.rtrack)
            @audio_status = Utils::FILE_ON_SERVER
        else
            @audio_status = Utils::FILE_NOT_FOUND
        end
        return @audio_status
    end


    def make_track_title(want_segment_title, want_track_number = true)
        title = ""
        title += track.iorder.to_s+". " unless track.iorder == 0 || !want_track_number
        if want_segment_title
            title += segment.stitle+" - " unless segment.stitle.empty?
            title += track.isegorder.to_s+". " unless track.isegorder == 0
        end
        return title+track.stitle
    end

    def html_track_title(want_segment_title, separator = "\n")
        return make_track_title(want_segment_title).to_html_bold + separator +
               "by "+artist.sname.to_html_italic + separator +
               "from "+record.stitle.to_html_italic
    end

    def html_track_title_no_track_num(want_segment_title, separator = "\n")
        return make_track_title(want_segment_title, false).to_html_bold + separator +
               "by "+artist.sname.to_html_italic + separator +
               "from "+record.stitle.to_html_italic
    end

    def html_record_title(separator = "\n")
        artist.ref_load(record.rartist) unless artist.rartist == record.rartist
        return record.stitle.to_html_bold + separator + "by "+artist.sname.to_html_italic
    end
end


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
        dialog.current_folder = default_dir.empty? ? Cfg::instance.music_dir : default_dir
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
        return File.exists?(fname) ? Gdk::Pixbuf.new(fname, 22, 22) : Gdk::Pixbuf.new(Cfg::instance.icons_dir+"default.svg", 22, 22)
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
        IO.foreach(Cfg::instance.rsrc_dir+"playedtracks.sql") { |line|
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
        count = DBIntf::connection.get_first_value("SELECT COUNT(rartist) FROM records WHERE rartist=#{rartist};")
        msg = "Error: #{count} reference(s) still in records table." if count > 0
        count = DBIntf::connection.get_first_value("SELECT COUNT(rartist) FROM segments WHERE rartist=#{rartist};")
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
        count = DBIntf::connection.get_first_value("SELECT COUNT(rsegment) FROM tracks WHERE rsegment=#{rsegment};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in tracks table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM segments WHERE rsegment=#{rsegment};")
        end
        return count
    end

    def UIUtils::delete_record(rrecord)
        count = DBIntf::connection.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rrecord=#{rrecord};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in segments table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils::client_sql("DELETE FROM records WHERE rrecord=#{rrecord};")
        end
        return count
    end

    def UIUtils::delete_track(rtrack)
        count = DBIntf::connection.get_first_value("SELECT COUNT(rpltrack) FROM pltracks WHERE rtrack=#{rtrack};")
        if count > 0
            UIUtils::show_message("Error: #{count} reference(s) still in play lists.", Gtk::MessageDialog::ERROR)
        else
            row = DBIntf.connection.execute("SELECT rsegment, rrecord FROM tracks WHERE rtrack=#{rtrack}")
            count = DBIntf.connection.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rsegment=#{row[0][0]}")
            del_seg = count == 1 && UIUtils::get_response("This is the last track of its segment. Remove it along?") == Gtk::Dialog::RESPONSE_OK
            count = DBIntf.connection.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{row[0][1]}")
            del_rec = count == 1 && UIUtils::get_response("This is the last track of its record. Remove it along?") == Gtk::Dialog::RESPONSE_OK

            DBUtils::client_sql("DELETE FROM logtracks WHERE rtrack=#{rtrack};")
            DBUtils::client_sql("DELETE FROM tracks WHERE rtrack=#{rtrack};")

            delete_segment(row[0][0]) if del_seg
            delete_record(row[0][1]) if del_rec
        end
        return count
    end

end
