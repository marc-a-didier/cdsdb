

#
# Provides audio files handling goodness
#
module Audio

    class Link < DBCache::Link

        attr_reader   :tags

        def initialize
            super
            reset
        end

        def reset
            @tags = nil
            return super
        end

        def audio_file
            return @tags.nil? ? super : @tags.file_name
        end

        def audio_status
            return @tags.nil? ? super : Status::OK
        end

        def load_from_tags(file_name)
            ftags = TagLib::File.new(file_name)
            @tags = Tags.new(ftags.artist, ftags.album, ftags.title, ftags.track,
                             ftags.length*1000, ftags.year, ftags.genre, file_name)
            ftags.close

            return self
        end

        # Builds the theoretical file name for a given track. Returns it WITHOUT extension.
        def build_audio_file_name
            return track.build_audio_file_name(segment_artist, record, segment, genre)

#             # If we have a segment, find the intra-segment order. If segmented and isegorder is 0, then the track
#             # is alone in its segment.
#             track_pos = 0
#             if record.segmented?
#                 track_pos = track.isegorder == 0 ? 1 : track.isegorder
#             end
#             # If we have a segment, prepend the title with the track position inside the segment
#             title = track_pos == 0 ? track.stitle : track_pos.to_s+". "+track.stitle
#
#             # If we have a compilation, the main dir is the record title as opposite to the standard case
#             # where it's the artist name
#             if record.compile?
#                 dir = File.join(record.stitle.clean_path, segment_artist.sname.clean_path)
#             else
#                 dir = File.join(segment_artist.sname.clean_path, record.stitle.clean_path)
#             end
#
#             fname = sprintf("%02d - %s", track.iorder, title.clean_path)
#             dir += "/"+segment.stitle.clean_path unless segment.stitle.empty?
#
#             return Cfg.music_dir+genre.sname+"/"+dir+"/"+fname
        end

        def setup_audio_file
            search_audio_file(build_audio_file_name) unless audio && audio.file

            return audio
        end

        # Returns the file name without the music dir and genre
        def track_dir(file_name)
            file = file_name.sub(Cfg.music_dir, "")
            return file.sub(file.split("/")[0], "")
        end

        def full_dir
            return File.dirname(audio.file)
        end

        def playable?
            return (audio_status == Status::OK || audio_status == Status::MISPLACED) && audio_file
        end

        # Search the Music directory for a file matching the theoretical file name.
        # If no match at first attempt, search in each first level directory of the Music directory.
        # Returns the status of for the file.
        # If a matching file is found, set the full name to the match.
        def search_audio_file(file_name)
            # Trace.debug("Search audio for track #{@rtrack.to_s.brown}")
            extensions = Cfg.size_over_quality ? FILE_EXTS_BY_SIZE : FILE_EXTS_BY_QUALITY

            extensions.each do |ext|
                if File.exists?(file_name+ext)
                    set_audio_state(Status::OK, file_name+ext)
                    return audio.status
                end
            end

            # Remove the root dir & genre dir to get the appropriate sub dir
            file = track_dir(file_name)
            Dir[Cfg.music_dir+"*"].each do |entry|
                next unless File.directory?(entry)
                extensions.each do |ext|
                    if File.exists?(entry+file+ext)
                        set_audio_state(Status::MISPLACED, entry+file+ext)
                        return audio.status
                    end
                end
            end

            set_audio_state(Status::NOT_FOUND, nil)
            return audio.status
        end

        def make_track_title(want_segment_title, want_track_number = true)
            title = ""
            if @tags.nil?
                title += track.iorder.to_s+". " unless track.iorder == 0 || !want_track_number
                if want_segment_title
                    title += segment.stitle+" - " unless segment.stitle.empty?
                    title += track.isegorder.to_s+". " unless track.isegorder == 0
                end
                title += track.stitle
            else
                title += @tags.track.to_s+". " if want_track_number
                title += @tags.title
            end
            return title
        end

        def tag_file(file_name)
            ftags = TagLib::File.new(file_name)
            ftags.artist = artist.sname
            ftags.album  = record.stitle
            ftags.title  = make_track_title(true, false) # Want segment title but no track number
            ftags.track  = track.iorder
            ftags.year   = record.iyear
            ftags.genre  = genre.sname
            ftags.save
            ftags.close
        end

        def tag_and_move_file(file_name)
            # Re-tags the original file
            tag_file(file_name)

            # Build the new name since some data used to build it may have changed
            set_audio_state(Status::OK, build_audio_file_name+File.extname(file_name))

            # Move the original file to it's new location
            root_dir = Cfg.music_dir+genre.sname+File::SEPARATOR
            FileUtils.mkpath(root_dir+File.dirname(track_dir(audio.file)))
            FileUtils.mv(file_name, audio.file)
            Log.info("Source #{file_name} tagged and moved to "+audio.file)
            Utils.remove_dirs(File.dirname(file_name))
        end

        def remove_from_fs
            setup_audio_file unless audio.file
            FileUtils.rm(audio.file)
            Utils.remove_dirs(File.dirname(audio.file))
        end

        def record_on_disk?
            setup_audio_file unless audio.file
            return Dir.exists?(File.dirname(audio.file))
        end

        #
        # Intended to be called if the db editor has been run to check if the track
        # should be re-tagged & moved.
        #
        # Fields that must be checked:
        #   artist :
        #       name -> mv folder & re-tag
        #   record :
        #       rartist
        #       title -> mv folder & re-tag
        #       genre -> mv folder & re-tag
        #   segment:
        #       rartist
        #       title -> mv folder & re-tag (only if seg name not empty)
        #   track  :
        #       title, order -> rename track & re-tag
        #       rrecord, rsegment
        #
        # Should get the old value and compare against new ones
        #
        def check_db_changes
            partist = DBClasses::Artist.new.ref_load(self.artist.rartist)
            precord = DBClasses::Record.new.ref_load(self.record.rrecord)
            psegment = DBClasses::Segment.new.ref_load(self.segment.rsegment)
            ptrack = DBClasses::Track.new.ref_load(self.track.rtrack)


        end
    end
end
