
class DiscAnalyzer


    ArtistStruct = Struct.new(:segments, :db_class)
    SegmentStruct = Struct.new(:tracks, :db_class)

    def initialize(disc)
        @disc = disc
    end

    def analyze_data
        # Find if the disc is a compilation
#         @disc.tracks.each_with_index do |track, index|
#             # Add new artist if doesn't exist
#             @artists[track.artist] = {} unless @artists[track.artist]
#
#             # Set segment name to empty if it has the name as the record
#             segment = @disc.title == track.segment ? "" : track.segment
#
#             # Add a new segment to the current artist if it doesn't already exist
#             @artist[track.artist][segment] = [] unless @artist[track.artist][segment]
#
#             # Add the track number to the current segment
#             @artist[track.artist][segment] << index
#         end

        artists = {}
        @disc.tracks.each_with_index do |track, index|
            # Add new artist if doesn't exist
            artists[track.artist] = ArtistStruct.new(Hash.new, ArtistDBclass.new) unless @artists[track.artist]

            # Set segment name to empty if it has the name as the record
            segment = @disc.title == track.segment ? "" : track.segment

            # Add a new segment to the current artist if it doesn't already exist
            artists[track.artist].segments = SegmentStruct.new(Array.new, SegmentDBClass.new) unless artists[track.artist].segments

            # Add the track number to the current segment
            artists[track.artist].segments[segment].tracks << index
        end

        last_id = artists[artists.keys[0]].db_class.get_last_id+1
        artists.each do |name, struct|
            struct.db_class.rartist = last_id
            struct.db_class.sname = name
            struct.db_class.generate_insert
            last_id += 1
        end

        record = RecordDBClass.new
        record.rartist = @artists.keys.size > 1 ? 0 : artist.rartist
        record.rrecord = record.get_last_id+1
        record.stitle = @disc.title
#         record.rgenre = GtkUI[GtkIDs::CDED_ENTRY_GENRE].text
        record.iyear = @disc.year
        record.slabel = @disc.label
        record.scatalog = @disc.catalog
        record.iplaytime = @disc.length
        record.icddbid = @disc.cddbid
        record.rmedia = @disc.medium
#         record.rlabel = @disc.label
        record.iissegmented = artists.size > 1 || artists.keys[0].segments.size > 1
        record.generate_insert

        last_id = artists[artists.keys[0]].segments[artists[artists.keys[0]].segments.keys[0]].db_class.get_last_id+1
        artists.each do |art_name, art_struct|
            art_struct.segments.each do |seg_name, seg_struct|
                seg_struct.db_class.rsegment = last_id
                seg_struct.db_class.stitle = seg_name
                seg_struct.tracks.each { |track_index| seg_struct.db_class.iplaytime += @disc.tracks[track_index].length }
                seg_struct.generate_insert
                last_id += 1
            end
        end

        track = TrackDBClass.new
        last_id = track.get_last_id+1
        @disc.tracks.each_with_index do |dtrack, track_index|
            track.rtrack = last_id
            track.rrecord = record.rrecord
            artists.each do |art_name, art_struct|
                art_struct.segments.each do |seg_name, seg_struct|
                    seg_struct.tracks.each { |seg_track| track.rsegment = seg_struct.db_class.rsegment if seg_track == track_index }
                end
            end
            track.stitle = dtrack.title
            track.iplaytime = dtrack.length
            track.generate_insert
            last_id += 1
        end
    end
end