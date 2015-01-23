

#
# Provides audio files handling goodness
#
class AudioLink < DBCacheLink

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
        return tags.nil? ? super : tags.file_name
    end

    def audio_status
        return tags.nil? ? super : Audio::Status::OK
    end

    def load_from_tags(file_name)
        tags = TagLib::File.new(file_name)
        @tags = Audio::Tags.new(tags.artist, tags.album, tags.title, tags.track,
                                tags.length*1000, tags.year, tags.genre, file_name)
        tags.close

        return self
    end

    # Builds the theoretical file name for a given track. Returns it WITHOUT extension.
    def build_audio_file_name
        # If we have a segment, find the intra-segment order. If segmented and isegorder is 0, then the track
        # is alone in its segment.
        track_pos = 0
        if record.segmented?
            track_pos = track.isegorder == 0 ? 1 : track.isegorder
        end
        # If we have a segment, prepend the title with the track position inside the segment
        title = track_pos == 0 ? track.stitle : track_pos.to_s+". "+track.stitle

        # If we have a compilation, the main dir is the record title as opposite to the standard case
        # where it's the artist name
        if record.compile?
            dir = File.join(record.stitle.clean_path, segment_artist.sname.clean_path)
        else
            dir = File.join(segment_artist.sname.clean_path, record.stitle.clean_path)
        end

        fname = sprintf("%02d - %s", track.iorder, title.clean_path)
        dir += "/"+segment.stitle.clean_path unless segment.stitle.empty?

        return CFG.music_dir+genre.sname+"/"+dir+"/"+fname
    end

    def setup_audio_file
        search_audio_file(build_audio_file_name) unless audio && audio.file

        return audio
    end

    # Returns the file name without the music dir and genre
    def track_dir(file_name)
        file = file_name.sub(CFG.music_dir, "")
        return file.sub(file.split("/")[0], "")
    end

    def full_dir
        return File.dirname(audio.file)
    end

    def playable?
        return (audio_status == Audio::Status::OK || audio_status == Audio::Status::MISPLACED) && audio.file
    end

    # Search the Music directory for a file matching the theoretical file name.
    # If no match at first attempt, search in each first level directory of the Music directory.
    # Returns the status of for the file.
    # If a matching file is found, set the full name to the match.
    def search_audio_file(file_name)
        # TRACE.debug("Search audio for track #{@rtrack.to_s.brown}")
        Audio::FILE_EXTS.each do |ext|
            if File.exists?(file_name+ext)
                set_audio_state(Audio::Status::OK, file_name+ext)
                return audio.status
            end
        end

        # Remove the root dir & genre dir to get the appropriate sub dir
        file = track_dir(file_name)
        Dir[CFG.music_dir+"*"].each do |entry|
            next unless File.directory?(entry)
            Audio::FILE_EXTS.each do |ext|
                if File.exists?(entry+file+ext)
                    set_audio_state(Audio::Status::MISPLACED, entry+file+ext)
                    return audio.status
                end
            end
        end

        set_audio_state(Audio::Status::NOT_FOUND, nil)
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
        tags = TagLib::File.new(file_name)
        tags.artist = artist.sname
        tags.album  = record.stitle
        tags.title  = make_track_title(true, false) # Want segment title but no track number
        tags.track  = track.iorder
        tags.year   = record.iyear
        tags.genre  = genre.sname
        tags.save
        tags.close
    end

    def tag_and_move_file(file_name)
        # Re-tags the original file
        tag_file(file_name)

        # Build the new name since some data used to build it may have changed
        set_audio_state(Audio::Status::OK, build_audio_file_name+File.extname(file_name))

        # Move the original file to it's new location
        root_dir = CFG.music_dir+genre.sname+File::SEPARATOR
        FileUtils.mkpath(root_dir+File.dirname(track_dir(audio.file)))
        FileUtils.mv(file_name, audio.file)
        LOG.info("Source #{file_name} tagged and moved to "+audio.file)
        Utils.remove_dirs(File.dirname(file_name))
    end

#     def tag_and_move_dir(dir, &call_back)
#         # Get track count
#         trk_count = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{record.rrecord}")
#
#         # Get recursivelly all music files from the selected dir
#         files = []
#         Find::find(dir) { |file|
#             #puts file;
#             files << [File::basename(file), File::dirname(file)] if Audio::FILE_EXTS.include?(File.extname(file).downcase)
#         }
#
#         # Check if track numbers contain a leading 0. If not rename the file with a leading 0.
#         files.each { |file|
#             if file[0] =~ /([^0-9]*)([0-9]+)(.*)/
#                 next if $2.length > 1
#                 nfile = $1+"0"+$2+$3
#                 FileUtils.mv(file[1]+File::SEPARATOR+file[0], file[1]+File::SEPARATOR+nfile)
#                 puts "File #{file[0]} renamed to #{nfile}"
#                 file[0] = nfile
#             end
#         }
#         # It looks like the sort method sorts on the first array keeping the second one synchronized with it.
#         files.sort! #.each { |file| puts "sorted -> file="+file[1]+" --- "+file[0] }
#
#         # Checks if the track count matches both the database and the directory
#         return [trk_count, files.size] if trk_count != files.size
#
#         # Loops through each track
#         i = 0
#         DBIntf.execute("SELECT rtrack FROM tracks WHERE rrecord=#{record.rrecord} ORDER BY iorder") do |row|
#             # Force to reset the link so it must update it's artist/segment in case of compilation
#             reset.set_track_ref(row[0])
#             # set_segment_ref(track.rsegment)
#             # set_artist_ref(segment.rartist)
#             tag_and_move_file(files[i][1]+File::SEPARATOR+files[i][0], &call_back)
#             i += 1
#         end
#         return [trk_count, files.size]
#     end

    def remove_from_fs
        setup_audio_file unless audio.file
        FileUtils.rm(audio.file)
        Utils.remove_dirs(File.dirname(audio.file))
    end

    def record_on_disk?
        setup_audio_file unless audio.file
        return Dir.exists?(File.dirname(audio.file))
    end
end
