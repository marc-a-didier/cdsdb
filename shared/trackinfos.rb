
#
# File system/Database track interface manager
#
#

class TrackInfos

    attr_reader :rec_art, :seg_art, :record, :segment, :track,
                :title, :genre, :dir, :fname

    def initialize
        @rec_art  = ArtistDBClass.new
        @seg_art  = ArtistDBClass.new
        @track    = TrackDBClass.new
        @segment  = SegmentDBClass.new
        @record   = RecordDBClass.new
    end

    def load_track(rtrack)
        return self if @track.rtrack == rtrack

        @track.ref_load(rtrack)
        @segment.ref_load(@track.rsegment) unless @segment.rsegment == @track.rsegment
        @record.ref_load(@track.rrecord) unless @record.rrecord == @track.rrecord
        @rec_art.ref_load(@record.rartist) unless @rec_art.rartist == @record.rartist
        if @record.compile?
            @seg_art.ref_load(@segment.rartist) unless @seg_art.rartist == @segment.rartist
        else
            @seg_art = @rec_art
        end
        return self
    end

    def build_access_infos
        # If we have a segment, find the intra-segment order. If segmented and isegorder is 0, then the track
        # is alone in its segment.
        track_pos = 0
        if @record.segmented?
            track_pos = track.isegorder == 0 ? 1 : track.isegorder
        end
        # If we have a segment, prepend the title with the track position inside the segment
        @title = track_pos == 0 ? @track.stitle : track_pos.to_s+". "+@track.stitle

        # If we have a compilation, the main dir is the record title as opposite to the standard case
        # where it's the artist name
        @dir = @record.compile? ?
            File.join(@record.stitle.clean_path, @seg_art.sname.clean_path) :
            File.join(@rec_art.sname.clean_path, @record.stitle.clean_path)

        @fname = sprintf("%02d - %s", @track.iorder, @title.clean_path)
        @genre = DBUtils::name_from_id(@record.rgenre, DBIntf::TBL_GENRES)
        @dir += "/"+@segment.stitle.clean_path unless @segment.stitle.empty?

        return self
    end

    def build_file_infos(rtrack)
        return load_track(rtrack).build_access_infos
    end

    def get_track_infos(rtrack)
        return build_file_infos(rtrack)
    end

    def get_full_dir
        return Cfg::instance.music_dir+@genre+"/"+@dir
    end

    def from_tags(fname)
        tags = TagLib::File.new(fname)
        @rec_art.sname   = @seg_art.sname = tags.artist
        @record.stitle   = tags.album
        @title           = tags.title
        @track.iorder    = tags.track
        @track.iplaytime = tags.length*1000
        @record.iyear    = tags.year
        @genre           = tags.genre
        tags.close

        return self
    end
end
