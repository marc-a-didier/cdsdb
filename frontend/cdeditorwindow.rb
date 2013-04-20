# encoding: utf-8

TrackData = Struct.new(:track, :title, :segment, :artist, :length)

DiscInfo = Struct.new(:title, :artist, :genre, :year, :length, :medium, :cddbid, :tracks)

class CDEditorWindow

    MODE_NONE = 0
    MODE_DISC = 1
    MODE_FILE = 2

    def initialize
        @glade = GTBld::load(UIConsts::CD_EDITOR_WINDOW)

        @window = @glade[UIConsts::CD_EDITOR_WINDOW]
        @tv = @glade[UIConsts::CDED_TV]

        @window.signal_connect(:show)         { PREFS.load_main(@glade, UIConsts::CD_EDITOR_WINDOW) }
        @window.signal_connect(:delete_event) { PREFS.save_window(@window); false }


        @tv.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_drag_received(widget, context, x, y, data, info, time) }
        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105], #DragType::URI_LIST],
                      ["text/plain", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @tv.enable_model_drag_dest(dragtable, Gdk::DragContext::ACTION_COPY)

        @glade[UIConsts::CDED_BTN_CP_ARTIST].signal_connect(:clicked) { on_cp_btn(3) }
        @glade[UIConsts::CDED_BTN_CP_TITLE].signal_connect(:clicked)  { on_cp_btn(2) }
        @glade[UIConsts::CDED_BTN_GENSQL].signal_connect(:clicked)    { generate_sql }
        @glade[UIConsts::CDED_BTN_SWAP].signal_connect(:clicked)      { swap_artists_titles }
        @glade["cded_btn_rip"].signal_connect(:clicked)               { rip_tracks }
        @glade[UIConsts::CDED_BTN_CLOSE].signal_connect(:clicked)     {
            PREFS.save_window(@window)
            @window.destroy
        }

        @mode = MODE_NONE
        @disc = nil

        @tv.model = Gtk::ListStore.new(Integer, String, String, String, String)

        ["Track", "Title", "Segment", "Artist", "Play time"].each_with_index { |title, i|
            renderer = Gtk::CellRendererText.new()
            if (1..3).include?(i)
                renderer.editable = true
                renderer.signal_connect(:edited) { |widget, path, new_text| @tv.selection.selected[i] = new_text }
            end
            @tv.append_column(Gtk::TreeViewColumn.new(title, renderer, :text => i))
        }

        @tv.columns.each { |column| column.resizable = true }
    end

    def on_cp_btn(column_id)
        @tv.model.each { |model, path, iter|
            iter[column_id] = column_id == 3 ? @glade[UIConsts::CDED_ENTRY_ARTIST].text : @glade[UIConsts::CDED_ENTRY_TITLE].text
        }
    end

    def swap_artists_titles
#         @tv.model.each { |model, path, iter| iter[1], iter[3] = iter[3], iter[1] }
        @tv.model.each { |model, path, iter|
            artist, title = iter[1].split(" / ")
            iter[1] = title
            iter[3] = artist
        }
    end

    def rip_tracks
        if @glade["cded_chk_flac"].active? || @glade["cded_chk_ogg"].active?
            @ripper.settings['flac'] = @glade["cded_chk_flac"].active?
            @ripper.settings['flacsettings'] = "--best -V"
            @ripper.settings['vorbis'] = @glade["cded_chk_ogg"].active?
            @ripper.settings['vorbissettings'] = "-q 8"
            Thread.new { @ripper.prepareRip }
        else
            UIUtils::show_message("Faudrait p't'êt' sélectionner un format, non?", Gtk::MessageDialog::ERROR)
        end
    end

    def generate_sql
        @disc.title = @glade[UIConsts::CDED_ENTRY_TITLE].text
        @disc.artist = @glade[UIConsts::CDED_ENTRY_ARTIST].text
        @disc.genre = @glade[UIConsts::CDED_ENTRY_GENRE].text
        @disc.year = @glade[UIConsts::CDED_ENTRY_YEAR].text.to_i

        @disc.tracks.each_with_index { |track, i|
            iter = @tv.model.get_iter(i.to_s)
            track.title = iter[1]
            track.segment = iter[2]
            track.artist = iter[3]
        }

        SQLGenerator.new.process_record(@disc)
    end

    def on_drag_received(widget, context, x, y, data, info, time)
        success = false
        if info == 105 #DragType::URI_LIST
            data.uris.each { |uri| add_audio_file(URI::unescape(uri).sub(/^file:\/\//, "")) }
            success = true
        end
        Gtk::Drag.finish(context, success, false, Time.now.to_i) #,time)
    end

    def add_track(track)
        iter = @tv.model.append
        iter[0] = track.track
        iter[1] = track.title
        iter[2] = track.segment
        iter[3] = track.artist
        iter[4] = track.length.to_ms_length
        @disc.length += track.length if @mode == MODE_FILE
    end

    def add_audio_file(file)
        tags = TagLib::File.new(file)

        track = TrackData.new
        track.track   = tags.track
        track.title   = tags.title
        track.segment = tags.album
        track.artist  = tags.artist
        track.length  = tags.length*1000
        @disc.tracks << track
        tags.close

        add_track(track)
    end

    def setup_tv
        @glade[UIConsts::CDED_ENTRY_TITLE].text = @disc.title
        @glade[UIConsts::CDED_ENTRY_ARTIST].text = @disc.artist
        @glade[UIConsts::CDED_ENTRY_GENRE].text = @disc.genre
        @glade[UIConsts::CDED_ENTRY_YEAR].text = @disc.year.to_s

        @disc.tracks.each { |track| add_track(track) }
    end

    def run
        @window.show
    end

    def edit_record()
        @ripper = RipperClient.new(CFG.cd_device)
        disc = @ripper.settings['cd'] #Disc.new(CFG.cd_device) # ("/dev/sr0")
        if disc.md.nil?
            UIUtils::show_message("Y'a même pas d'CD dans ta croûte de pc, pauv' tanche!!!", Gtk::MessageDialog::INFO)
            return Gtk::Dialog::RESPONSE_CANCEL
        end

        #disc.md.freedb($rr_defaultSettings)
        if disc.md.tracklist.size == 0
            UIUtils::show_message("Disc not found on freedb!", Gtk::MessageDialog::INFO)
            return Gtk::Dialog::RESPONSE_CANCEL
        end

        @disc = DiscInfo.new
        @disc.tracks = []
        @disc.title = disc.md.album
        @disc.artist = disc.md.artist
        @disc.genre = disc.md.genre
        @disc.year = disc.md.year
        @disc.length = disc.mSecPT
        @disc.cddbid = disc.freedbString.split()[0].hex.to_s
        @disc.medium = DBIntf::MEDIA_CD

        disc.audiotracks.times { |i|
            track = TrackData.new
            track.track = i+1
            track.title = disc.md.tracklist[i]
            track.segment = @disc.title
            track.artist = disc.md.varArtists.empty? ? @disc.artist : disc.md.varArtists[i]
            track.length = disc.mSecLength[i]
            @disc.tracks << track
        }

        setup_tv
        run
    end

    def edit_audio_file(file)
        @mode = MODE_FILE

        tags = TagLib::File.new(file)
        @disc = DiscInfo.new
        @disc.tracks = []
        @disc.title = tags.album
        @disc.artist = tags.artist
        @disc.genre = tags.genre
        @disc.year = tags.year
        @disc.length = 0 # tags.length*1000
        @disc.cddbid = DBIntf::NULL_CDDBID
        @disc.medium = DBIntf::MEDIA_AUDIO_FILE
        tags.close

        setup_tv

        add_audio_file(file)

        run
    end
end
