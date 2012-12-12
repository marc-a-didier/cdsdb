
#
# This file now contains all of the db/user interface interaction classes
#

#
# The next classes handle the interaction with the tabs of the main window
#
#
class ArtistUI < ArtistDBClass

    include BaseUI
    include MainTabsUI

    def initialize(glade)
        super()
        @glade = glade
        init_baseui("art_tab_")
    end

    def to_widgets
        super
        return to_infos_widget(@glade[UIConsts::MW_INFLBL_ARTIST])
    end

    def build_infos_string
        return "" if not self.valid? or self.rorigin == 0
        str  = DBUtils::name_from_id(self.rorigin, "origin")
        return str
    end
end

class RecordUI < RecordDBClass

    include BaseUI
    include MainTabsUI


    def initialize(glade)
        super()
        @glade = glade
        init_baseui("rec_tab_")
    end

    def to_widgets
        super
        return to_infos_widget(@glade[UIConsts::MW_INFLBL_RECORD])
    end


    def build_infos_string
        return "" unless self.valid?
        str  = DBUtils::name_from_id(self.rmedia, "media")
        str += self.iyear == 0 ? ", Unknown" : ", "+self.iyear.to_s
        str += ", "+DBUtils::name_from_id(self.rlabel, "label")
        str += ", "+self.scatalog unless self.scatalog.empty?
        str += ", "+DBUtils::name_from_id(self.rgenre, "genre")
        str += ", "+self.isetorder.to_s+" of "+self.isetof.to_s if self.isetorder > 0
        str += ", "+DBUtils::name_from_id(self.rcollection, "collection") if self.rcollection != 0
        str += ", "+self.iplaytime.to_ms_length
    end
end

class SegmentUI < SegmentDBClass

    include BaseUI
    include MainTabsUI

    def initialize(glade)
        super()
        @glade = glade
        init_baseui("seg_tab_")
    end

    def to_widgets
        super
        return to_infos_widget(@glade[UIConsts::MW_INFLBL_RECORD])
    end

    def build_infos_string
        return "" unless self.valid?
        str  = "Segment "+self.iorder.to_s
        str += " "+self.stitle unless self.stitle.empty?
        str += " by "+DBUtils::name_from_id(self.rartist, "artist")
        str += " "+self.iplaytime.to_ms_length
    end
end

class TrackUI < TrackDBClass

    include BaseUI
    include MainTabsUI

    attr_reader :uilink

    def initialize(glade)
        super()
        @glade = glade
        @curr_pix_key = ""
        @uilink = nil
        init_baseui("trk_tab_")
    end

    def set_uilink(uilink)
        @uilink = uilink
        return clone_dbs(uilink.track) # self
    end

    def to_widgets
        super
        return to_infos_widget(@glade[UIConsts::MW_INFLBL_TRACK])
    end

    def to_widgets_with_cover #(trk_mgr)
        @glade[UIConsts::REC_IMAGE].pixbuf = @uilink.large_track_cover if @uilink.cover_key.empty? || @uilink.cover_key != @curr_pix_key
        @curr_pix_key = @uilink.cover_key
        return to_widgets
    end

    def build_infos_string
        return "" unless self.valid?
        str  = UIConsts::RATINGS[self.irating]+", "
        str += self.iplayed > 0 ? "played "+self.iplayed.to_s+" time".check_plural(self.iplayed)+" " : "never played, "
        str += "(Last: "+self.ilastplayed.to_std_date+"), " if self.ilastplayed != 0
        if self.itags == 0
            str += "no tags"
        else
            str += "tagged as "
            UIConsts::TAGS.each_with_index { |tag, i| str += tag+" " if (self.itags & (1 << i)) != 0 }
        end
        return str
    end
end


#
# Classes that handle the full stand-alone editor to the underlying db structure
#
#
class ArtistEditor < ArtistDBClass

    include UIConsts
    include BaseUI

    def initialize(glade, rartist)
        super()

        @glade = glade
        init_baseui("arted_")

        ref_load(rartist)

        @glade[ARTED_BTN_ORIGIN].signal_connect(:clicked) { select_dialog("rorigin") }
    end
end


class RecordEditor < RecordDBClass

    include UIConsts
    include BaseUI

    def initialize(glade, rrecord)
        super()

        @glade = glade
        init_baseui("reced_")

        ref_load(rrecord)

        @glade[RECED_BTN_ARTIST].signal_connect(:clicked)     { select_dialog("rartist") }
        @glade[RECED_BTN_GENRE].signal_connect(:clicked)      { select_dialog("rgenre") }
        @glade[RECED_BTN_LABEL].signal_connect(:clicked)      { select_dialog("rlabel") }
        @glade[RECED_BTN_MEDIUM].signal_connect(:clicked)     { select_dialog("rmedia") }
        @glade[RECED_BTN_COLLECTION].signal_connect(:clicked) { select_dialog("rcollection") }
        @glade[RECED_BTN_PTIME].signal_connect(:clicked)      { update_ptime }

        [RECED_BTN_ARTIST, RECED_BTN_LABEL, RECED_BTN_MEDIUM, RECED_BTN_PTIME].each { |ctrl|
            @glade[ctrl].sensitive = Cfg::instance.admin?
        }
    end

    def update_ptime
        return if rmedia != DBIntf::MEDIA_AUDIO_FILE
        DBUtils::update_record_playtime(self.rrecord)
        self.field_to_widget("iplaytime")
    end

end


class SegmentEditor < SegmentDBClass

    include UIConsts
    include BaseUI

    def initialize(glade, rsegment)
        super()

        @glade = glade
        init_baseui("seged_")

        ref_load(rsegment)

        @glade[SEGED_BTN_ARTIST].signal_connect(:clicked) { select_dialog("rartist") }
        @glade[SEGED_BTN_PTIME].signal_connect(:clicked)  { update_ptime }

        [SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
            @glade[ctrl].sensitive = Cfg::instance.admin?
        }
    end

    def update_ptime
        DBUtils::update_segment_playtime(self.rsegment)
        #DBUtils::update_record_playtime(self.rrecord)
        self.field_to_widget("iplaytime")
    end

end


class TrackEditor < TrackDBClass

    include UIConsts
    include BaseUI

    def initialize(glade, rtrack)
        super()

        @glade = glade
        init_baseui("trked_")

        ref_load(rtrack)

        #
        # Setup the rating combo
        #
        RATINGS.each { |rating| @glade[TRKED_CMB_RATING].append_text(rating) }

        #
        # Setup the track tags treeview
        #
        UIUtils::setup_tracks_tags_tv(@glade[UIConsts::TRKED_TV_TAGS])
    end
end

class DBEditor

    include UIConsts

    def initialize(mc, initiating_class)
        @glade = GTBld::load(DLG_DB_EDITOR)

        @editors = []
        @editors << ArtistEditor.new(@glade, mc.record.compile? ? mc.segment.rartist : mc.artist.rartist)
        @editors << RecordEditor.new(@glade, mc.record.rrecord)
        @editors << SegmentEditor.new(@glade, mc.segment.rsegment)
        @editors << TrackEditor.new(@glade, mc.track.rtrack)
        @editors.each { |editor| editor.to_widgets }

        @glade[DBED_NBOOK].page = 0 if initiating_class.instance_of?(ArtistUI)
        @glade[DBED_NBOOK].page = 1 if initiating_class.instance_of?(RecordUI)
        @glade[DBED_NBOOK].page = 2 if initiating_class.instance_of?(SegmentUI)
        @glade[DBED_NBOOK].page = 3 if initiating_class.instance_of?(TrackUI)
    end

    def run
        @glade[DBED_BTN_OK].sensitive = Cfg::instance.admin?

        response = @glade[DLG_DB_EDITOR].run
        if response == Gtk::Dialog::RESPONSE_OK
            @editors.each { |editor| editor.from_widgets.sql_update } #.to_widgets(_with_cover) ???
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
