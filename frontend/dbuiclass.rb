
#
# This file now contains all of the db/user interface interaction classes
#

#
# The next classes handle the interaction with the tabs of the main window
#
#
class ArtistUI < DBCacheLink

    def initialize
        super
    end

    def valid?
        return !@rartist.nil?
    end

    def to_widgets
        GtkUI[GtkIDs::MW_INFLBL_ARTIST].text = build_infos_string
        GtkUI[GtkIDs::MEMO_ARTIST].buffer.text = valid? ? artist.mnotes.to_memo : ""
    end

    def from_widgets
        artist.mnotes = GtkUI[GtkIDs::MEMO_ARTIST].buffer.text.to_dbstring
        artist.sql_update
        return self
    end

    def build_infos_string
        return "" if !valid? || artist.rorigin == 0
        return DBCACHE.origin(artist.rorigin).sname
    end
end


class RecordUI < DBCacheLink

    def initialize
        super
    end

    def valid?
        return !@rrecord.nil?
    end

    def to_widgets(is_record)
        GtkUI[GtkIDs::MW_INFLBL_RECORD].text = is_record ? build_rec_infos_string : build_seg_infos_string
        GtkUI[GtkIDs::MEMO_RECORD].buffer.text  = valid? ? record.mnotes.to_memo : ""
        GtkUI[GtkIDs::MEMO_SEGMENT].buffer.text = valid? ? segment.mnotes.to_memo : ""
        return self
    end

    def from_widgets
        record.mnotes = GtkUI[GtkIDs::MEMO_RECORD].buffer.text.to_dbstring
        record.sql_update
        segment.mnotes = GtkUI[GtkIDs::MEMO_SEGMENT].buffer.text.to_dbstring
        segment.sql_update
        return self
    end

    def build_rec_infos_string
        return "" unless valid?
        rec = DBCACHE.record(@rrecord) # Cache of the cache!!!
        str  = DBCACHE.media(rec.rmedia).sname
        str += rec.iyear == 0 ? ", Unknown" : ", "+rec.iyear.to_s
        str += ", "+DBCACHE.label(record.rlabel).sname
        str += ", "+rec.scatalog unless rec.scatalog.empty?
        str += ", "+genre.sname
        str += ", "+rec.isetorder.to_s+" of "+rec.isetof.to_s if rec.isetorder > 0
        str += ", "+DBCACHE.collection(rec.rcollection).sname if rec.rcollection != 0
        str += ", "+rec.iplaytime.to_ms_length
        str += " [%8.4f | %8.4f]" % [rec.fgain, rec.fpeak]
    end

    def build_seg_infos_string
        return "" unless valid?
        str  = "Segment "+segment.iorder.to_s
        str += " "+segment.stitle unless segment.stitle.empty?
        str += " by "+segment_artist.sname+" "+segment.iplaytime.to_ms_length
    end
end


class TrackUI < UILink

    def initialize
        super
    end

    def valid?
        return !@rtrack.nil?
    end

    def to_widgets
        GtkUI[GtkIDs::MW_INFLBL_TRACK].text   = build_infos_string
        GtkUI[GtkIDs::MEMO_TRACK].buffer.text = valid? ? track.mnotes.to_memo : ""
        return self
    end

    # TODO: find a way to not redraw image each time if not changed
    def to_widgets_with_cover
        GtkUI[GtkIDs::REC_IMAGE].pixbuf = large_track_cover #if @pix_key.empty? || @curr_pix_key != @pix_key
        return to_widgets
    end

    def from_widgets
        track.mnotes = GtkUI[GtkIDs::MEMO_TRACK].buffer.text.to_dbstring
        track.sql_update
        return self
    end

    def build_infos_string
        return "" unless valid?
        trk = DBCACHE.track(@rtrack) # Cache of the cache!!!
        str  = Qualifiers::RATINGS[trk.irating]+", "
        str += trk.iplayed > 0 ? "played "+trk.iplayed.to_s+" time".check_plural(trk.iplayed)+" " : "never played, "
        str += "(Last: "+trk.ilastplayed.to_std_date+"), " if trk.ilastplayed != 0
        if trk.itags == 0
            str += "no tags"
        else
            str += "tagged as "
            Qualifiers::TAGS.each_with_index { |tag, i| str += tag+" " if (trk.itags & (1 << i)) != 0 }
        end
        str += " [%8.4f | %8.4f]" % [trk.fgain, trk.fpeak]
        return str
    end
end


#
# Classes that handle the full stand-alone editor to the underlying db structure
#
#
#
# Now that editors work with the cache and do not inherit from any class,
# the @dbs and @glade members must be set since they are used in the
# included BaseUI module.
#

class ArtistEditor

    include GtkIDs
    include BaseUI

    def initialize(dbs)
        @dbs = dbs
        init_baseui("arted_")

        GtkUI[ARTED_BTN_ORIGIN].signal_connect(:clicked) { select_dialog("rorigin") }
    end
end


class RecordEditor

    include GtkIDs
    include BaseUI

    def initialize(dbs)
        @dbs = dbs
        init_baseui("reced_")

        GtkUI[RECED_BTN_ARTIST].signal_connect(:clicked)     { select_dialog("rartist") }
        GtkUI[RECED_BTN_GENRE].signal_connect(:clicked)      { select_dialog("rgenre") }
        GtkUI[RECED_BTN_LABEL].signal_connect(:clicked)      { select_dialog("rlabel") }
        GtkUI[RECED_BTN_MEDIUM].signal_connect(:clicked)     { select_dialog("rmedia") }
        GtkUI[RECED_BTN_COLLECTION].signal_connect(:clicked) { select_dialog("rcollection") }
        GtkUI[RECED_BTN_PTIME].signal_connect(:clicked)      { update_ptime }

        [RECED_BTN_ARTIST, RECED_BTN_LABEL, RECED_BTN_MEDIUM, RECED_BTN_PTIME].each { |ctrl|
            GtkUI[ctrl].sensitive = CFG.admin?
        }
    end

    def update_ptime
        return if rmedia != DBIntf::MEDIA_AUDIO_FILE
        DBUtils::update_record_playtime(@dbs.rrecord)
        @dbs.sql_load
        self.field_to_widget("iplaytime")
    end

end


class SegmentEditor

    include GtkIDs
    include BaseUI

    def initialize(dbs)
        @dbs = dbs
        init_baseui("seged_")

        GtkUI[SEGED_BTN_ARTIST].signal_connect(:clicked) { select_dialog("rartist") }
        GtkUI[SEGED_BTN_PTIME].signal_connect(:clicked)  { update_ptime }

        [SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
            GtkUI[ctrl].sensitive = CFG.admin?
        }
    end

    def update_ptime
        DBUtils::update_segment_playtime(@dbs.rsegment)
        @dbs.sql_load
        #DBUtils::update_record_playtime(self.rrecord)
        self.field_to_widget("iplaytime")
    end

end


class TrackEditor

    include GtkIDs
    include BaseUI

    def initialize(dbs)
        @dbs = dbs
        init_baseui("trked_")

        #
        # Setup the rating combo
        #
        Qualifiers::RATINGS.each { |rating| GtkUI[TRKED_CMB_RATING].append_text(rating) }

        #
        # Setup the track tags treeview
        #
        UIUtils::setup_tracks_tags_tv(GtkUI[TRKED_TV_TAGS])
    end
end

class DBEditor

    include GtkIDs

    def initialize(mc, dblink, default_page)
        GtkUI.load_window(DLG_DB_EDITOR)

        @dblink = dblink

        # Try to set a maximum of reference if possible
        @dblink.set_segment_ref(@dblink.track.rsegment) if !@dblink.valid_segment_ref? && @dblink.valid_track_ref?
        @dblink.set_record_ref(@dblink.segment.rrecord) if !@dblink.valid_record_ref? && @dblink.valid_segment_ref?
        @dblink.set_artist_ref(@dblink.segment.rartist) if !@dblink.valid_artist_ref? && @dblink.valid_segment_ref?

        # Add editor only if there are data for it
        @editors = [nil, nil, nil, nil]
        @editors[0] = ArtistEditor.new(@dblink.artist)   if @dblink.valid_artist_ref?
        @editors[1] = RecordEditor.new(@dblink.record)   if @dblink.valid_record_ref?
        @editors[2] = SegmentEditor.new(@dblink.segment) if @dblink.valid_segment_ref?
        @editors[3] = TrackEditor.new(@dblink.track)     if @dblink.valid_track_ref?

        # Set data to fields or remove page if no data. Do it backward so it doesn't screw with page
        # number since pages are in the tables hierarchy order
        3.downto(0) { |i|  @editors[i] ? @editors[i].to_widgets : GtkUI[DBED_NBOOK].remove_page(i) }

        GtkUI[DBED_NBOOK].page = default_page # default page is in theory always visible
    end

    def run
        GtkUI[DBED_BTN_OK].sensitive = CFG.admin?

        response = GtkUI[DLG_DB_EDITOR].run
        if response == Gtk::Dialog::RESPONSE_OK
            @editors.each { |dbs| dbs.from_widgets if dbs }
            @dblink.flush_main_tables
        end
        GtkUI[DLG_DB_EDITOR].destroy
        return response
    end
end

class PListDialog < PListDBClass

    include GtkIDs
    include BaseUI

    def initialize(rplist)
        super()

        GtkUI.load_window(DLG_PLIST_INFOS)
        @dbs = self
        init_baseui("pldlg_")

        ref_load(rplist)
    end

    def run
        to_widgets
        GtkUI[DLG_PLIST_INFOS].run
        GtkUI[DLG_PLIST_INFOS].destroy
    end
end
