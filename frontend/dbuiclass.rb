
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
        GTBld.main[UIConsts::MW_INFLBL_ARTIST].text = build_infos_string
        GTBld.main[UIConsts::MEMO_ARTIST].buffer.text = valid? ? artist.mnotes.to_memo : ""
    end

    def from_widgets
        artist.mnotes = GTBld.main[UIConsts::MEMO_ARTIST].buffer.text.to_dbstring
        artist.sql_update
        return self
    end

    def build_infos_string
        return "" if !valid? || artist.rorigin == 0
        return cache.origin(artist.rorigin).sname
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
        GTBld.main[UIConsts::MW_INFLBL_RECORD].text = is_record ? build_rec_infos_string : build_seg_infos_string
        GTBld.main[UIConsts::MEMO_RECORD].buffer.text  = valid? ? record.mnotes.to_memo : ""
        GTBld.main[UIConsts::MEMO_SEGMENT].buffer.text = valid? ? segment.mnotes.to_memo : ""
        return self
    end

    def from_widgets
        record.mnotes = GTBld.main[UIConsts::MEMO_RECORD].buffer.text.to_dbstring
        record.sql_update
        segment.mnotes = GTBld.main[UIConsts::MEMO_SEGMENT].buffer.text.to_dbstring
        segment.sql_update
        return self
    end

    def build_rec_infos_string
        return "" unless valid?
        rec = cache.record(@rrecord) # Cache of the cache!!!
        str  = cache.media(rec.rmedia).sname
        str += rec.iyear == 0 ? ", Unknown" : ", "+rec.iyear.to_s
        str += ", "+cache.label(record.rlabel).sname
        str += ", "+rec.scatalog unless rec.scatalog.empty?
        str += ", "+genre.sname
        str += ", "+rec.isetorder.to_s+" of "+rec.isetof.to_s if rec.isetorder > 0
        str += ", "+cache.collection(rec.rcollection).sname if rec.rcollection != 0
        str += ", "+rec.iplaytime.to_ms_length
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
        GTBld.main[UIConsts::MW_INFLBL_TRACK].text   = build_infos_string
        GTBld.main[UIConsts::MEMO_TRACK].buffer.text = valid? ? track.mnotes.to_memo : ""
        return self
    end

    # TODO: find a way to not redraw image each time if not changed
    def to_widgets_with_cover
        GTBld.main[UIConsts::REC_IMAGE].pixbuf = large_track_cover #if @pix_key.empty? || @curr_pix_key != @pix_key
        return to_widgets
    end

    def from_widgets
        track.mnotes = GTBld.main[UIConsts::MEMO_TRACK].buffer.text.to_dbstring
        track.sql_update
        return self
    end

    def build_infos_string
        return "" unless valid?
        trk = cache.track(@rtrack) # Cache of the cache!!!
        str  = UIConsts::RATINGS[trk.irating]+", "
        str += trk.iplayed > 0 ? "played "+trk.iplayed.to_s+" time".check_plural(trk.iplayed)+" " : "never played, "
        str += "(Last: "+trk.ilastplayed.to_std_date+"), " if trk.ilastplayed != 0
        if trk.itags == 0
            str += "no tags"
        else
            str += "tagged as "
            UIConsts::TAGS.each_with_index { |tag, i| str += tag+" " if (trk.itags & (1 << i)) != 0 }
        end
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

    include UIConsts
    include BaseUI

    def initialize(glade, dbs)
        @glade = glade
        @dbs = dbs
        init_baseui("arted_")

        glade[ARTED_BTN_ORIGIN].signal_connect(:clicked) { select_dialog("rorigin") }
    end
end


class RecordEditor

    include UIConsts
    include BaseUI

    def initialize(glade, dbs)
        @glade = glade
        @dbs = dbs
        init_baseui("reced_")

        glade[RECED_BTN_ARTIST].signal_connect(:clicked)     { select_dialog("rartist") }
        glade[RECED_BTN_GENRE].signal_connect(:clicked)      { select_dialog("rgenre") }
        glade[RECED_BTN_LABEL].signal_connect(:clicked)      { select_dialog("rlabel") }
        glade[RECED_BTN_MEDIUM].signal_connect(:clicked)     { select_dialog("rmedia") }
        glade[RECED_BTN_COLLECTION].signal_connect(:clicked) { select_dialog("rcollection") }
        glade[RECED_BTN_PTIME].signal_connect(:clicked)      { update_ptime }

        [RECED_BTN_ARTIST, RECED_BTN_LABEL, RECED_BTN_MEDIUM, RECED_BTN_PTIME].each { |ctrl|
            glade[ctrl].sensitive = Cfg::instance.admin?
        }
    end

    def update_ptime
        return if rmedia != DBIntf::MEDIA_AUDIO_FILE
        DBUtils::update_record_playtime(@dbs.rrecord)
        self.field_to_widget("iplaytime")
    end

end


class SegmentEditor

    include UIConsts
    include BaseUI

    def initialize(glade, dbs)
        @glade = glade
        @dbs = dbs
        init_baseui("seged_")

        glade[SEGED_BTN_ARTIST].signal_connect(:clicked) { select_dialog("rartist") }
        glade[SEGED_BTN_PTIME].signal_connect(:clicked)  { update_ptime }

        [SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
            glade[ctrl].sensitive = Cfg::instance.admin?
        }
    end

    def update_ptime
        DBUtils::update_segment_playtime(@dbs.rsegment)
        #DBUtils::update_record_playtime(self.rrecord)
        self.field_to_widget("iplaytime")
    end

end


class TrackEditor

    include UIConsts
    include BaseUI

    def initialize(glade, dbs)
        @glade = glade
        @dbs = dbs
        init_baseui("trked_")

        #
        # Setup the rating combo
        #
        RATINGS.each { |rating| glade[TRKED_CMB_RATING].append_text(rating) }

        #
        # Setup the track tags treeview
        #
        UIUtils::setup_tracks_tags_tv(glade[TRKED_TV_TAGS])
    end
end

class DBEditor

    include UIConsts

    def initialize(mc, initiating_class)
        @glade = GTBld::load(DLG_DB_EDITOR)

        @dblink = mc.new_link_from_selection

        @editors = []
        @editors << ArtistEditor.new(@glade, @dblink.artist.dbs)
        @editors << RecordEditor.new(@glade, @dblink.record.dbs)
        @editors << SegmentEditor.new(@glade, @dblink.segment.dbs)
        @editors << TrackEditor.new(@glade, @dblink.track.dbs)
        @editors.each { |editor| editor.to_widgets }

        # TODO: a revoir!!! maintenant que rec & seg sont dans la meme ui...
        @glade[DBED_NBOOK].page = 0 if initiating_class.kind_of?(ArtistDBClass)
        @glade[DBED_NBOOK].page = 1 if initiating_class.kind_of?(RecordDBClass)
        @glade[DBED_NBOOK].page = 2 if initiating_class.kind_of?(SegmentDBClass)
        @glade[DBED_NBOOK].page = 3 if initiating_class.kind_of?(TrackDBClass)
    end

    def run
        @glade[DBED_BTN_OK].sensitive = Cfg::instance.admin?

        response = @glade[DLG_DB_EDITOR].run
        if response == Gtk::Dialog::RESPONSE_OK
            @editors.each { |dbs| dbs.from_widgets }
            @dblink.flush_main_tables
        end
        @glade[DLG_DB_EDITOR].destroy
        return response
    end
end

class PListDialog < PListDBClass

    include UIConsts
    include BaseUI

    def initialize(rplist)
        super()

        @glade = GTBld::load(DLG_PLIST_INFOS)
        init_baseui("pldlg_")

        ref_load(rplist)
    end

    def run
        to_widgets
        @glade[DLG_PLIST_INFOS].run
        @glade[DLG_PLIST_INFOS].destroy
    end
end
