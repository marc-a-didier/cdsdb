
#
# Analyze and generate SQL statements to add a new record to the DB.
#
#
# Things to remember:
#   - Compilations are NOT marked as segmented unless there are trully segments.
#   - A record with only one segment which has a different title than the record is NOT marked as segmented.
#
#

module DiscAnalyzer

    RESULT_SQL_FILE = Cfg.rsrc_dir+'discanalyzer.sql'

    ArtistStruct = Struct.new(:segments, :db_class)
    SegmentStruct = Struct.new(:tracks, :db_class)

    def self.format_artist(artist)
        return "Unknown" if artist.empty?

        return artist.match(/^the |^die |^les /i) ? artist[4..-1]+", "+artist[0..2] : artist
    end

    # Check if an entry already exists in the db. If not, add a new insert statement to the file
    def self.get_reference(klass, ref, f)
        if ref.empty?
            klass[0] = 0
        else
            unless klass.select_by_field("sname", ref, :case_insensitive)
                klass[0] = klass.get_last_id+1
                klass.sname = ref
                f.puts(klass.generate_insert)
            end
        end
        return klass
    end

    def self.analyze(disc, f)
        genre = self.get_reference(DBClasses::Genre.new, disc.genre, f)
        label = self.get_reference(DBClasses::Label.new, disc.label, f)

        # Builds a structure that groups tracks into segments and segements into artists
        seg_order = 0
        artists = {}
        disc.tracks.each_with_index do |track, index|
            # Format artist name
            name = self.format_artist(track.artist)

            # Add new artist if doesn't exist
            artists[name] = ArtistStruct.new(Hash.new, DBClasses::Artist.new) unless artists[name]

            # Set segment name to empty if it has the name as the record
            segment = disc.title == track.segment ? "" : track.segment

            # Add a new segment to the current artist if it doesn't already exist
            unless artists[name].segments[segment]
                artists[name].segments[segment] = SegmentStruct.new(Array.new, DBClasses::Segment.new)
                # Already set segment order in db class cause can't find it again since it's a hash
                seg_order += 1
                artists[name].segments[segment].db_class.iorder = seg_order
            end

            # Add the track number to the current segment
            artists[name].segments[segment].tracks << index
        end

        # Keep a flag that say if the record is segmented or not
        is_segmented = false
        artists.each { |name, struct| is_segmented = true if struct.segments.size > 1 }

        # Iterate through artists and add those who are missing in the db
        last_id = artists[artists.keys[0]].db_class.get_last_id+1
        artists.each do |name, struct|
            unless struct.db_class.select_by_field("sname", name, :case_insensitive)
                struct.db_class.rartist = last_id
                struct.db_class.sname = name
                f.puts(struct.db_class.generate_insert)
                last_id += 1
            end
        end

        # Setup the record entry and generate the insert statement
        record = DBClasses::Record.new
        record.rartist = artists.size > 1 ? 0 : artists[artists.keys[0]].db_class.rartist
        record.rrecord = record.get_last_id+1
        record.stitle = disc.title
        record.rgenre = genre.rgenre
        record.iyear = disc.year
        record.rlabel = label.rlabel
        record.scatalog = disc.catalog
        record.iplaytime = disc.length
        record.icddbid = disc.cddbid.to_i
        record.rmedia = disc.medium
        record.idateadded = Time.now.to_i
        record.iissegmented = is_segmented ? 1 : 0
        record.itrackscount = disc.tracks.size
        f.puts(record.generate_insert)

        # Generate insert statement for each segment
        last_id = artists[artists.keys[0]].segments[artists[artists.keys[0]].segments.keys[0]].db_class.get_last_id+1
        artists.each do |art_name, art_struct|
            art_struct.segments.each do |seg_name, seg_struct|
                seg_struct.db_class.rsegment = last_id
                seg_struct.db_class.rartist = art_struct.db_class.rartist
                seg_struct.db_class.rrecord = record.rrecord
                seg_struct.db_class.stitle = seg_name
                seg_struct.tracks.each { |track_index| seg_struct.db_class.iplaytime += disc.tracks[track_index].length }
                f.puts(seg_struct.db_class.generate_insert)
                last_id += 1
            end
        end

        # Generate the insert statement for each track.
        # Getting back the segment reference and segment order is a bit tricky!!!
        track = DBClasses::Track.new
        last_id = track.get_last_id+1
        disc.tracks.each_with_index do |dtrack, track_index|
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
            track.iorder = track_index+1
            track.stitle = dtrack.title
            track.iplaytime = dtrack.length
            f.puts(track.generate_insert)
            last_id += 1
        end
    end

    def self.process(disc)
        File.open(RESULT_SQL_FILE, "w") { |f| self.analyze(disc, f) }
    end
end
