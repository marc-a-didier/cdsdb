
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
        to_infos_widget(@glade[UIConsts::MW_INFLBL_ARTIST])
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

    attr_reader :cover_file_name
    
    def initialize(glade)
        super()
        @glade = glade
        init_baseui("rec_tab_")
    end

    def to_widgets
        super
        to_infos_widget(@glade[UIConsts::MW_INFLBL_RECORD])
    end
    
    def to_widgets_with_img
        @cover_file_name = Utils::get_cover_file_name(self.rrecord, 0, self.irecsymlink)
        @glade[UIConsts::REC_IMAGE].pixbuf = IconsMgr::instance.get_cover(self.rrecord, 0, self.irecsymlink, 128)
        to_infos_widget(@glade[UIConsts::MW_INFLBL_RECORD])
        return to_widgets
    end

    def build_infos_string
        return "" unless self.valid?
        str  = DBUtils::name_from_id(self.rmedia, "media")
        str += self.iyear == 0 ? ", Unknown" : ", "+self.iyear.to_s
        str += ", "+DBUtils::name_from_id(self.rlabel, "label")
        str += ", "+self.scatalog unless self.scatalog.empty?
        str += ", "+DBUtils::name_from_id(self.rgenre, "genre")
        str += ", "+self.isetorder.to_s+" of "+self.isetof.to_s if self.iisinset > 0
        str += ", "+DBUtils::name_from_id(self.rcollection, "collection") if self.rcollection != 0
        str += ", "+Utils::format_ms_length(self.iplaytime)
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
        to_infos_widget(@glade[UIConsts::MW_INFLBL_RECORD])
    end

    def build_infos_string
        return "" unless self.valid?
        str  = "Segment "+self.iorder.to_s
        str += " "+self.stitle unless self.stitle.empty?
        str += " by "+DBUtils::name_from_id(self.rartist, "artist")
        str += " "+Utils::format_ms_length(self.iplaytime)
    end
end

class TrackUI < TrackDBClass

    include BaseUI
    include MainTabsUI

    def initialize(glade)
        super()
        @glade = glade
        @cover_file_name = ""
        init_baseui("trk_tab_")
    end

    def to_widgets
        super
        to_infos_widget(@glade[UIConsts::MW_INFLBL_TRACK])
    end

    def to_widgets_with_img(record)
        fname = IconsMgr::instance.track_cover(self.rrecord, self.rtrack)
        if fname == ""
            if record.cover_file_name != @cover_file_name
                @glade[UIConsts::REC_IMAGE].pixbuf = IconsMgr::instance.get_cover(self.rrecord, 0, record.irecsymlink, 128)
            end
            @cover_file_name = record.cover_file_name
        else
            @glade[UIConsts::REC_IMAGE].pixbuf = IconsMgr::instance.get_cover(self.rrecord, self.rtrack, 0, 128)
            @cover_file_name = fname
        end
        to_infos_widget(@glade[UIConsts::MW_INFLBL_TRACK])
        return to_widgets
    end
    
    def build_infos_string
        return "" unless self.valid?
        str  = UIConsts::RATINGS[self.irating]+", "
        str += self.iplayed > 0 ? "played "+self.iplayed.to_s+Utils::check_plural(" time", self.iplayed)+" " : "never played, "
        str += "(Last: "+Utils::format_date(self.ilastplayed)+"), " if self.ilastplayed != 0
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

        @glade = glade #GTBld::load(DLG_DB_EDITOR) #DLG_ART_EDITOR)
        init_baseui("arted_")

        ref_load(rartist)

        @glade[ARTED_BTN_ORIGIN].signal_connect(:clicked) { select_dialog("rorigin") }
    end

    def run
        #[ARTED_BTN_OK, ARTED_BTN_ORIGIN].each { |ctrl| @glade[ctrl].sensitive = Cfg::instance.admin? }
        artist = nil
        self.to_widgets
        #artist = self.from_widgets.sql_update if @glade[DLG_ART_EDITOR].run == Gtk::Dialog::RESPONSE_OK
        @glade[DLG_DB_EDITOR].run == Gtk::Dialog::RESPONSE_OK
        #@glade[DLG_ART_EDITOR].destroy
        @glade[DLG_DB_EDITOR].destroy
        return artist
    end

end


class RecordEditor < RecordDBClass

    include UIConsts
    include BaseUI

    def initialize(glade, rrecord)
        super()

        @glade = glade #GTBld::load(DLG_REC_EDITOR)
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

    def run
#         [RECED_BTN_OK, RECED_BTN_ARTIST, RECED_BTN_LABEL, RECED_BTN_MEDIUM, RECED_BTN_PTIME].each { |ctrl|
#             @glade[ctrl].sensitive = Cfg::instance.admin?
#         }

        record = nil
        self.to_widgets
        record = self.from_widgets.sql_update if @glade[DLG_REC_EDITOR].run == Gtk::Dialog::RESPONSE_OK
        @glade[DLG_REC_EDITOR].destroy
        return record
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

        @glade = glade #GTBld::load(DLG_SEG_EDITOR)
        init_baseui("seged_")

        ref_load(rsegment)

        @glade[SEGED_BTN_ARTIST].signal_connect(:clicked) { select_dialog("rartist") }
        @glade[SEGED_BTN_PTIME].signal_connect(:clicked)  { update_ptime }

        [SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
            @glade[ctrl].sensitive = Cfg::instance.admin?
        }
    end

    def run
#         [SEGED_BTN_OK, SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
#             @glade[ctrl].sensitive = Cfg::instance.admin?
#         }

        segment = nil
        to_widgets
        segment = self.from_widgets.sql_update if @glade[DLG_SEG_EDITOR].run == Gtk::Dialog::RESPONSE_OK
        @glade[DLG_SEG_EDITOR].destroy
        return segment
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

        @glade = glade #GTBld::load(DLG_TRK_EDITOR)
        init_baseui("trked_")

        ref_load(rtrack)

        #
        # Setup the rating combo
        #
        #@glade[TRKED_CMB_RATING].remove_text(0)
        RATINGS.each { |rating| @glade[TRKED_CMB_RATING].append_text(rating) }

        #
        # Setup the track tags treeview
        #
        UIUtils::setup_tracks_tags_tv(@glade[UIConsts::TRKED_TV_TAGS])
    end

    def run
        @glade[TRKED_BTN_OK].sensitive = Cfg::instance.admin?

        track = nil
        to_widgets
        track = self.from_widgets.sql_update if @glade[DLG_TRK_EDITOR].run == Gtk::Dialog::RESPONSE_OK
        @glade[DLG_TRK_EDITOR].destroy
        return track
    end
end

class DBEditor

    include UIConsts
    
    def initialize(mc, initiating_class)
        @glade = GTBld::load(DLG_DB_EDITOR)

        @editors = []
        if mc.record.compile?
            @editors << ArtistEditor.new(@glade, mc.segment.rartist)
        else
            @editors << ArtistEditor.new(@glade, mc.artist.rartist)
        end
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
            @editors.each { |editor| editor.from_widgets.sql_update } #.to_widgets(_with_img) ???
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
