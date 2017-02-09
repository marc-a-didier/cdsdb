
class CDEditorWindow

    MODE_NONE = 0
    MODE_DISC = 1
    MODE_FILE = 2

    def initialize
        GtkUI.load_window(GtkIDs::CD_EDITOR_WINDOW)

        @window = GtkUI[GtkIDs::CD_EDITOR_WINDOW]
        @tv = GtkUI[GtkIDs::CDED_TV]

        @window.signal_connect(:show)         { Prefs.restore_window(GtkIDs::CD_EDITOR_WINDOW) }
        @window.signal_connect(:delete_event) { Prefs.save_window(GtkIDs::CD_EDITOR_WINDOW); false }


        @tv.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_drag_received(widget, context, x, y, data, info, time) }
        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105], #DragType::URI_LIST],
                      ["text/plain", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @tv.enable_model_drag_dest(dragtable, Gdk::DragContext::ACTION_COPY)

        GtkUI[GtkIDs::CDED_BTN_CP_ARTIST].signal_connect(:clicked) { on_cp_btn(3) }
        GtkUI[GtkIDs::CDED_BTN_CP_TITLE].signal_connect(:clicked)  { on_cp_btn(2) }
        GtkUI[GtkIDs::CDED_BTN_GENSQL].signal_connect(:clicked)    { generate_sql }
        GtkUI[GtkIDs::CDED_BTN_MERGE].signal_connect(:clicked)     { query_and_merge }
        GtkUI[GtkIDs::CDED_BTN_QUERY].signal_connect(:clicked) do
            case GtkUI[GtkIDs::CDED_CMB_SOURCE].active
                when 0 then @disc = @feeder.query_freedb(Cfg.cd_device).disc
                when 1 then @disc = @feeder.query_musicbrainz(Cfg.cd_device).disc
            end
            update_tv
        end
        GtkUI[GtkIDs::CDED_CMB_SOURCE].active = 0
        GtkUI[GtkIDs::CDED_BTN_CLOSE].signal_connect(:clicked) do
            Prefs.save_window(GtkIDs::CD_EDITOR_WINDOW)
            @window.destroy
        end

        @mode = MODE_NONE
        @disc = nil

        @tv.model = Gtk::ListStore.new(Integer, String, String, String, String)

        ["Track", "Title", "Segment", "Artist", "Duration"].each_with_index do |title, i|
            renderer = Gtk::CellRendererText.new()
            if (1..3).include?(i)
                renderer.editable = true
                renderer.signal_connect(:edited) { |widget, path, new_text| @tv.selection.selected[i] = new_text }
            end
            @tv.append_column(Gtk::TreeViewColumn.new(title, renderer, :text => i))
        end

        @tv.columns.each { |column| column.resizable = true }

        # Popup menu
        GtkUI[GtkIDs::CDED_SWAPAT].signal_connect(:activate)     { swap_artists_titles }
        GtkUI[GtkIDs::CDED_SPLITAT].signal_connect(:activate)    { split_artists_titles }
        GtkUI[GtkIDs::CDED_IMPTITLES].signal_connect(:activate)  { import_artists_titles }
        GtkUI[GtkIDs::CDED_CAPTITLES].signal_connect(:activate)  { capitalize_titles }
        GtkUI[GtkIDs::CDED_CAPARTISTS].signal_connect(:activate) { capitalize_artists }

        @tv.signal_connect(:button_press_event) { |widget, event| show_popup(widget, event) }
    end

    def show_popup(widget, event)
        if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3   # left mouse button
            GtkUI[GtkIDs::CDED_POPUP].popup(nil, nil, event.button, event.time)
        end
    end

    def on_cp_btn(column_id)
        @tv.model.each do |model, path, iter|
            iter[column_id] = column_id == 3 ? GtkUI[GtkIDs::CDED_ENTRY_ARTIST].text : GtkUI[GtkIDs::CDED_ENTRY_TITLE].text
        end
    end

    def capitalize(str)
        return str.split(' ').each(&:downcase!).each(&:capitalize!).join(' ')
    end

    def split_artists_titles
        @tv.model.each do |model, path, iter|
            artist, title = iter[1].split(" - ")
            iter[1] = title
            iter[3] = artist
        end
    end

    def swap_artists_titles
        @tv.model.each { |model, path, iter| iter[1], iter[3] = iter[3], iter[1] }
    end

    def import_artists_titles
        dir = GtkUtils.select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER, Cfg.rip_dir)
        return if dir.empty?

        path = 0
        Dir[dir+'/*'].sort.each do |entry|
            next if File.directory?(entry)
            # K3B format : 'nn - artist - title.ext' compile???
            #              'nn - title.ext' if not compile???
            artist = ''
            if File.basename(entry).split(' - ').size < 3
                track, title = File.basename(entry).split(' - ')
            else
                track, artist, title = File.basename(entry).split(' - ')
            end
            iter = @tv.model.get_iter(path.to_s)
            iter[1] = title.sub(/\.[^.]*$/, '')
            iter[3] = artist
            path += 1
        end
    end

    def capitalize_titles
        @tv.model.each { |model, path, iter| iter[1] = capitalize(iter[1]) }
    end

    def capitalize_artists
        @tv.model.each { |model, path, iter| iter[3] = capitalize(iter[3]) }
    end

    def query_and_merge
        disc = @feeder.query_musicbrainz(Cfg.cd_device).disc
        @disc.year = disc.year if @disc.year == 0
        @disc.label = disc.label
        @disc.catalog = disc.catalog
        update_tv
    end

    def generate_sql
        @disc.title = GtkUI[GtkIDs::CDED_ENTRY_TITLE].text
        @disc.artist = GtkUI[GtkIDs::CDED_ENTRY_ARTIST].text
        @disc.genre = GtkUI[GtkIDs::CDED_ENTRY_GENRE].text
        @disc.year = GtkUI[GtkIDs::CDED_ENTRY_YEAR].text.to_i
        @disc.label = GtkUI[GtkIDs::CDED_ENTRY_LABEL].text
        @disc.catalog = GtkUI[GtkIDs::CDED_ENTRY_CATALOG].text

        @disc.tracks.each_with_index do |track, i|
            iter = @tv.model.get_iter(i.to_s)
            track.title = iter[1]
            track.segment = iter[2]
            track.artist = iter[3]
        end

        DiscAnalyzer.process(@disc)
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

        track = CDDataFeeder::TrackData.new
        track.track   = tags.track
        track.title   = tags.title
        track.segment = tags.album
        track.artist  = tags.artist
        track.length  = tags.length*1000
        @disc.tracks << track
        tags.close

        add_track(track)
    end

    def update_tv
        @tv.model.clear

        GtkUI[GtkIDs::CDED_ENTRY_TITLE].text = @disc.title
        GtkUI[GtkIDs::CDED_ENTRY_ARTIST].text = @disc.artist
        GtkUI[GtkIDs::CDED_ENTRY_GENRE].text = @disc.genre
        GtkUI[GtkIDs::CDED_ENTRY_YEAR].text = @disc.year.to_s
        GtkUI[GtkIDs::CDED_ENTRY_LABEL].text = @disc.label
        GtkUI[GtkIDs::CDED_ENTRY_CATALOG].text = @disc.catalog

        @disc.tracks.each { |track| add_track(track) }
    end

    def run
        @window.show
    end

    def edit_record
        @feeder = CDDataFeeder.new
        @disc = @feeder.query_freedb(Cfg.cd_device).disc
#         @disc = feeder.query_musicbrainz(Cfg.cd_device).disc
        if @disc.nil?
            GtkUtils.show_message("Y'a un souci, mon gars... pas d'CD, pas de connection ou pas de résultat pour ta galette...", Gtk::MessageDialog::INFO)
            return Gtk::Dialog::RESPONSE_CANCEL
        end

        update_tv
        run
    end

    def edit_audio_file(file)
        @mode = MODE_FILE

        tags = TagLib::File.new(file)
        @disc = CDDataFeeder::DiscInfo.new.reset
        @disc.title = tags.album
        @disc.artist = tags.artist
        @disc.genre = tags.genre
        @disc.year = tags.year
        @disc.length = 0 # tags.length*1000
        @disc.cddbid = DBIntf::NULL_CDDBID
        @disc.medium = Audio::MEDIA_FILE
        tags.close

        update_tv

        add_audio_file(file)

        run
    end
end
