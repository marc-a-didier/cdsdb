
TooltipCache = Struct.new(:link, :text)

#
# Module that handle search and caching of image for a track and/or record.
# It feeds the ImageCache with asked for tracks/records and maintains
# the TrackKeyCache hash to speed search for track covers.
#
module CoverMgr

    def record_in_cache?(rrecord, irecsymlink)
        @pix_key = irecsymlink == 0 ? "r"+rrecord.to_s : "r"+irecsymlink.to_s
        return IMG_CACHE.has_key(@pix_key)
    end

    def get_cover_file_name
        files = Dir[CFG.covers_dir+@pix_key[1..-1]+".*"] # Skip 'r'.
        # TRACE.debug "CoverMgr search key #{@pix_key} - disk access".red
        return files.size > 0 ? File::basename(files[0]) : ImageCache::DEF_RECORD_FILE
    end

    # @pix_key is set by record_in_cache? since we always check the hash before the file system
    def load_record_cover(rrecord, irecsymlink, size)
        file = get_cover_file_name
        if file == ImageCache::DEF_RECORD_FILE
            return IMG_CACHE.set_default_pix(@pix_key, size)
        else
            return IMG_CACHE.load_cover(@pix_key, size, file)
        end
    end


    #
    # Only these 3 methods should be called, the other are for private use.
    #
    # They should be called only of @pix_key is empty. It's faster to get the pix
    # directly from the cache from @pix_key.
    #
    def track_pix(rtrack, rrecord, irecsymlink, size)
        @pix_key = "t"+rtrack.to_s
        if IMG_CACHE.has_key(@pix_key)
            return IMG_CACHE.pix(@pix_key, size)
        else
            return record_pix(rrecord, irecsymlink, size)
        end
    end

    def record_pix(rrecord, irecsymlink, size)
        if record_in_cache?(rrecord, irecsymlink)
            return IMG_CACHE.pix(@pix_key, size)
        else
            return load_record_cover(rrecord, irecsymlink, size)
        end
    end

    # Returns the full file name for the cover to display.
    def file_name(rtrack, rrecord, irecsymlink)
        @pix_key = "t"+rtrack.to_s
        if !IMG_CACHE.has_key(@pix_key) && !record_in_cache?(rrecord, irecsymlink)
            IMG_CACHE.set_file_name(@pix_key, get_cover_file_name)
        end
        return IMG_CACHE.full_name(@pix_key)
    end
end


#
# Extends AudioLink and include CoverMgr to add UI related functions
# like covers, html titles, etc...
#
class UILink < AudioLink

    include CoverMgr

    def initialize
        super
        reset
    end

    def reset
        @use_record_gain = false
        @pix_key = ""
        return super
    end

    def load_from_tags(file_name)
        @pix_key = ImageCache::DEFAULT_COVER
        return super
    end

    def set_use_of_record_gain
        @use_record_gain = true
        return self
    end

    def use_record_gain?
        return @use_record_gain
    end

    def cover_file_name
        @pix_key.empty? ? file_name(track.rtrack, track.rrecord, record.irecsymlink) :
                          IMG_CACHE.full_name(@pix_key)
    end

    def large_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_track_cover
        @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def large_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::LARGE_SIZE)
    end

    def small_record_cover
        @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, ImageCache::SMALL_SIZE) :
                          IMG_CACHE.pix(@pix_key, ImageCache::SMALL_SIZE)
    end

    def cover_key
        return @pix_key
    end

    def available_on_server?
        if audio_status == AudioStatus::NOT_FOUND && CFG.remote?
            if MusicClient.new.check_multiple_audio(track.rtrack.to_s+" ")[0].to_i != AudioStatus::NOT_FOUND
                set_audio_status(AudioStatus::ON_SERVER)
            end
        end
        return audio_status == AudioStatus::ON_SERVER
    end

    def get_audio_file(emitter, tasks)
        # Try to find a local file if status is unknown
        setup_audio_file if audio_status == AudioStatus::UNKNOWN || audio.file.nil?

        # If status is on server, get the remote file.
        return get_remote_audio_file(emitter, tasks) if available_on_server?

        return audio_status
    end

    def get_remote_audio_file(emitter, tasks)
        if CFG.remote? && CFG.local_store?
            unless tasks.track_in_download?(self)
                tasks.new_track_download(emitter, self)
                set_audio_status(AudioStatus::ON_SERVER)
            end
        else
            set_audio_status(AudioStatus::NOT_FOUND)
        end
        return audio_status
    end


    def set_cover(url, is_compile)
        fname = URI::unescape(url)
        return self unless fname.match(/^file:\/\//) # We may get http urls...

        fname.sub!(/^file:\/\//, "")
        if record.rartist == 0 && !is_compile
            # We're on a track of a compilation but not on the Compilations
            # so we assign the file to the track rather than the record
            cover_file = CFG.covers_dir+record.rrecord.to_s
            FileUtils::mkpath(cover_file)
            cover_file += File::SEPARATOR+track.rtrack.to_s+File::extname(fname)
            ex_name = cover_file+File::SEPARATOR+"ex"+track.rtrack.to_s+File::extname(fname)
        else
            # Assign file to record
            cover_file = CFG.covers_dir+record.rrecord.to_s+File::extname(fname)
            ex_name = CFG.covers_dir+"ex"+record.rrecord.to_s+File::extname(fname)
        end
        if File::exists?(cover_file)
            File::unlink(ex_name) if File::exists?(ex_name)
            FileUtils::mv(cover_file, ex_name)
        end
        #File::unlink(cover_file) if File::exists?(cover_file)
        FileUtils::mv(fname, cover_file)

        # Force the cache to reload new image
        load_record_cover(record.rrecord, record.irecsymlink, ImageCache::LARGE_SIZE)

        return self
    end

    def html_track_title(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title).to_html_bold + separator +"by "
        title += @tags.nil? ? segment_artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_track_title_no_track_num(want_segment_title, separator = "\n")
        title = make_track_title(want_segment_title, false).to_html_bold + separator +"by "
        title += @tags.nil? ? segment_artist.sname.to_html_italic : @tags.artist.to_html_italic
        title += separator + "from "
        title += @tags.nil? ? record.stitle.to_html_italic : @tags.album.to_html_italic
        return title
    end

    def html_record_title(separator = "\n")
        return record.stitle.to_html_bold + separator + "by "+record_artist.sname.to_html_italic
    end

    def markup_tooltip
        text = "<b>Genre:</b> #{genre.sname}\n"
        text += "<b>Played:</b> #{track.iplayed}"
        text += track.ilastplayed == 0 ? "\n" : " (Last: #{track.ilastplayed.to_std_date})\n"
        text += "<b>Rating:</b> #{Qualifiers::RATINGS[track.irating]}\n"
        text += "<b>Tags:</b> "
        if track.itags == 0
            text += "No tags"
        else
            Qualifiers::TAGS.each_with_index { |tag, i| text += tag+" " if (track.itags & (1 << i)) != 0 }
        end
        return text
    end
end
