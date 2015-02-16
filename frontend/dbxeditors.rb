#
# Classes that handle the full stand-alone editor to the underlying db structure
#
#
#
# Now that editors work with the cache and do not inherit from any class.
# A dbs structure must be provided and everything is handled by the WidgetsController module.
#

module XIntf

    module Editors

        # These constants are used by callers to tell which page of the main editor
        # should be the default one
        ARTIST_PAGE  = 0
        RECORD_PAGE  = 1
        SEGMENT_PAGE = 2
        TRACK_PAGE   = 3


        class Artist

            include GtkIDs
            include WidgetsController

            def initialize(dbs)
                setup_controls("arted_", dbs)

                GtkUI[ARTED_BTN_ORIGIN].signal_connect(:clicked) { select_dialog(:rorigin) }
            end
        end


        class Record

            include GtkIDs
            include WidgetsController

            def initialize(dbs)
                setup_controls("reced_", dbs)

                GtkUI[RECED_BTN_ARTIST].signal_connect(:clicked)     { select_dialog(:rartist) }
                GtkUI[RECED_BTN_GENRE].signal_connect(:clicked)      { select_dialog(:rgenre) }
                GtkUI[RECED_BTN_LABEL].signal_connect(:clicked)      { select_dialog(:rlabel) }
                GtkUI[RECED_BTN_MEDIUM].signal_connect(:clicked)     { select_dialog(:rmedia) }
                GtkUI[RECED_BTN_COLLECTION].signal_connect(:clicked) { select_dialog(:rcollection) }
                GtkUI[RECED_BTN_PTIME].signal_connect(:clicked)      { update_ptime }

                [RECED_BTN_ARTIST, RECED_BTN_LABEL, RECED_BTN_MEDIUM, RECED_BTN_PTIME].each { |ctrl|
                    GtkUI[ctrl].sensitive = Cfg.admin
                }
            end

            def update_ptime
                return if rmedia != DBIntf::MEDIA_AUDIO_FILE
                DBUtils::update_record_playtime(@dbs.rrecord)
                @dbs.sql_load
                self.field_to_widget("iplaytime")
            end
        end


        class Segment

            include GtkIDs
            include WidgetsController

            def initialize(dbs)
                setup_controls("seged_", dbs)

                GtkUI[SEGED_BTN_ARTIST].signal_connect(:clicked) { select_dialog(:rartist) }
                GtkUI[SEGED_BTN_PTIME].signal_connect(:clicked)  { update_ptime }

                [SEGED_BTN_ARTIST, SEGED_BTN_PTIME].each { |ctrl|
                    GtkUI[ctrl].sensitive = Cfg.admin
                }
            end

            def update_ptime
                DBUtils::update_segment_playtime(@dbs.rsegment)
                @dbs.sql_load
                #DBUtils::update_record_playtime(self.rrecord)
                self.field_to_widget("iplaytime")
            end
        end


        class Track

            include GtkIDs
            include WidgetsController

            def initialize(dbs)
                setup_controls("trked_", dbs)

                #
                # Setup the rating combo
                #
                Qualifiers::RATINGS.each { |rating| GtkUI[TRKED_CMB_RATING].append_text(rating) }

                #
                # Setup the track tags treeview
                #
                GtkUtils.setup_tracks_tags_tv(GtkUI[TRKED_TV_TAGS])
            end
        end

        class Main

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
                @editors[0] = Artist.new(@dblink.artist)   if @dblink.valid_artist_ref?
                @editors[1] = Record.new(@dblink.record)   if @dblink.valid_record_ref?
                @editors[2] = Segment.new(@dblink.segment) if @dblink.valid_segment_ref?
                @editors[3] = Track.new(@dblink.track)     if @dblink.valid_track_ref?

                # Set data to fields or remove page if no data. Do it backward so it doesn't screw with page
                # number since pages are in the tables hierarchy order
                3.downto(0) { |i|  @editors[i] ? @editors[i].to_widgets : GtkUI[DBED_NBOOK].remove_page(i) }

                GtkUI[DBED_NBOOK].page = default_page # default page is in theory always visible
            end

            def run
                GtkUI[DBED_BTN_OK].sensitive = Cfg.admin

                response = GtkUI[DLG_DB_EDITOR].run
                if response == Gtk::Dialog::RESPONSE_OK
                    @editors.each { |dbs| dbs.from_widgets if dbs }
                    @dblink.flush_main_tables
                end
                GtkUI[DLG_DB_EDITOR].destroy
                return response
            end
        end

        class PList < DBClasses::PList

            include GtkIDs
            include WidgetsController

            def initialize(rplist)
                super()

                GtkUI.load_window(DLG_PLIST_INFOS)
                setup_controls("pldlg_", self)

                ref_load(rplist)
            end

            def run
                to_widgets
                GtkUI[DLG_PLIST_INFOS].run
                GtkUI[DLG_PLIST_INFOS].destroy
            end
        end
    end
end
