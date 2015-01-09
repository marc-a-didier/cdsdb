
class DiscAnalyzer

    ArtistStruct = Struct.new(:segments, :db_class)
    SegmentStruct = Struct.new(:tracks, :db_class)

    def initialize(disc)
#         @disc = disc
        @disc = CDEditorWindow::DiscInfo.new
        f = File.open(CFG.rsrc_dir+'analyzer.sql', "w")

        @disc.title = "Disc standard"
        @disc.artist = "Artist standard"
        @disc.genre = "Punk"
        @disc.label = "Fat Wreck Chords"
        @disc.catalog = "FAT 0007"
        @disc.year = 2020
        @disc.length = 123456
        @disc.cddbid = 0x00001
        @disc.medium = DBIntf::MEDIA_CD
        @disc.tracks = []
        10.times { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", @disc.title, @disc.artist, 10000) }
        analyze_data(f)
        f.puts

        @disc.title = "Disc with segments"
        @disc.artist = "Artist standard"
        @disc.genre = "disc.md.genre"
        @disc.label = "Fat Wreck"
        @disc.catalog = "FAT 0008"
        @disc.year = 2025
        @disc.length = 234567
        @disc.cddbid = 0x00002
        @disc.medium = DBIntf::MEDIA_CD
        @disc.tracks = []
        (1..4).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 1", @disc.artist, 10000) }
        (5..8).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 2", @disc.artist, 10000) }
        analyze_data(f)
        f.puts

        @disc.title = "Compilation disc"
        @disc.artist = "Compilation"
        @disc.genre = "disc.md.genre"
        @disc.label = "Fat Wreck"
        @disc.catalog = "FAT 0009"
        @disc.year = 2026
        @disc.length = 345678
        @disc.cddbid = 0x00002
        @disc.medium = DBIntf::MEDIA_CD
        @disc.tracks = []
        (1..2).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", @disc.title, "artist 1", 10000) }
        (3..4).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", @disc.title, "artist 2", 10000) }
        (5..6).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", @disc.title, "artist 3", 10000) }
        (7..8).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", @disc.title, "artist 1", 10000) }
        analyze_data(f)
        f.puts


        @disc.title = "Compilation disc with segments"
        @disc.artist = "Compilation"
        @disc.genre = "disc.md.genre"
        @disc.label = "Fat Wreck Chords"
        @disc.catalog = "FAT 0010"
        @disc.year = 2027
        @disc.length = 456789
        @disc.cddbid = 0x00002
        @disc.medium = DBIntf::MEDIA_CD
        @disc.tracks = []
        (1..2).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 1", "artist 1", 10000) }
        (3..4).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 2", "artist 2", 10000) }
        (5..6).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 3", "artist 3", 10000) }
        (7..8).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 4", "artist 1", 10000) }
        analyze_data(f)
        f.puts

        @disc.title = "Standard disc with segment name other than disc title"
        @disc.artist = "nofx"
        @disc.genre = "disc.md.genre"
        @disc.label = "Fat Wreck Chords"
        @disc.catalog = "FAT 0011"
        @disc.year = 2028
        @disc.length = 456789
        @disc.cddbid = 0x00002
        @disc.medium = DBIntf::MEDIA_CD
        @disc.tracks = []
        (1..6).each { |i| @disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment title", @disc.artist, 10000) }
        analyze_data(f)
        f.puts

        f.close
    end

    def get_reference(klass, ref, f)
        unless klass.select_by_field("sname", ref, :case_insensitive)
            klass[0] = klass.get_last_id+1
            klass.sname = ref
            f.puts(klass.generate_insert)
        end
        return klass
    end

    def analyze_data(f)
#         f = File.open(CFG.rsrc_dir+'discanalyzer.sql', "w")

        genre = get_reference(GenreDBClass.new, @disc.genre, f)
        label = get_reference(LabelDBClass.new, @disc.label, f)

        artists = {}
        @disc.tracks.each_with_index do |track, index|
            # Add new artist if doesn't exist
            artists[track.artist] = ArtistStruct.new(Hash.new, ArtistDBClass.new) unless artists[track.artist]

            # Set segment name to empty if it has the name as the record
            segment = @disc.title == track.segment ? "" : track.segment

            # Add a new segment to the current artist if it doesn't already exist
            artists[track.artist].segments[segment] = SegmentStruct.new(Array.new, SegmentDBClass.new) unless artists[track.artist].segments[segment]

            # Add the track number to the current segment
            artists[track.artist].segments[segment].tracks << index
        end

        is_segmented = false
        artists.each { |name, struct| is_segmented = true if struct.segments.size > 1 }

        last_id = artists[artists.keys[0]].db_class.get_last_id+1
        artists.each do |name, struct|
            unless struct.db_class.select_by_field("sname", name, :case_insensitive)
                struct.db_class.rartist = last_id
                struct.db_class.sname = name
                f.puts(struct.db_class.generate_insert)
                last_id += 1
            end
        end

        record = RecordDBClass.new
        record.rartist = artists.keys.size > 1 ? 0 : artists[artists.keys[0]].db_class.rartist
        record.rrecord = record.get_last_id+1
        record.stitle = @disc.title
        record.rgenre = genre.rgenre
        record.iyear = @disc.year
        record.rlabel = label.rlabel
        record.scatalog = @disc.catalog
        record.iplaytime = @disc.length
        record.icddbid = @disc.cddbid
        record.rmedia = @disc.medium
        record.iissegmented = is_segmented ? 1 : 0
        f.puts(record.generate_insert)

        last_id = artists[artists.keys[0]].segments[artists[artists.keys[0]].segments.keys[0]].db_class.get_last_id+1
        artists.each do |art_name, art_struct|
            art_struct.segments.each do |seg_name, seg_struct|
                seg_struct.db_class.rsegment = last_id
                seg_struct.db_class.rartist = art_struct.db_class.rartist
                seg_struct.db_class.rrecord = record.rrecord
                seg_struct.db_class.stitle = seg_name
                seg_struct.tracks.each { |track_index| seg_struct.db_class.iplaytime += @disc.tracks[track_index].length }
                f.puts(seg_struct.db_class.generate_insert)
                last_id += 1
            end
        end

        track = TrackDBClass.new
        last_id = track.get_last_id+1
        @disc.tracks.each_with_index do |dtrack, track_index|
            track.isegorder = 0
            track.rtrack = last_id
            track.rrecord = record.rrecord
            artists.each do |art_name, art_struct|
                art_struct.segments.each do |seg_name, seg_struct|
                    seg_struct.tracks.each_with_index do |seg_track, seg_order|
                        if seg_track == track_index
                            track.rsegment = seg_struct.db_class.rsegment
                            track.isegorder = seg_order+1 if is_segmented
                        end
                    end
                end
            end
            track.stitle = dtrack.title
            track.iplaytime = dtrack.length
            f.puts(track.generate_insert)
            last_id += 1
        end

#         f.close
    end
end
