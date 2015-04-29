
module XIntf

    TooltipCache = Struct.new(:link, :text)

    #
    # Extends Audio::Link and include Covers module to add UI capabilities
    # like covers, html titles, etc...
    #
    class Link < Audio::Link

        include Covers

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
            @pix_key = Image::Cache::DEFAULT_COVER
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
                              Image::Cache.full_name(@pix_key)
        end

        def large_track_cover
            @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, Image::Cache::LARGE_SIZE) :
                              Image::Cache.pix(@pix_key, Image::Cache::LARGE_SIZE)
        end

        def small_track_cover
            @pix_key.empty? ? track_pix(track.rtrack, track.rrecord, record.irecsymlink, Image::Cache::SMALL_SIZE) :
                              Image::Cache.pix(@pix_key, Image::Cache::SMALL_SIZE)
        end

        def large_record_cover
            @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, Image::Cache::LARGE_SIZE) :
                              Image::Cache.pix(@pix_key, Image::Cache::LARGE_SIZE)
        end

        def small_record_cover
            @pix_key.empty? ? record_pix(record.rrecord, record.irecsymlink, Image::Cache::SMALL_SIZE) :
                              Image::Cache.pix(@pix_key, Image::Cache::SMALL_SIZE)
        end

        def cover_key
            return @pix_key
        end

        def available_on_server?
            if audio_status == Audio::Status::NOT_FOUND && Cfg.remote?
                if MusicClient.check_multiple_audio(track.rtrack.to_s+" ")[0].to_i != Audio::Status::NOT_FOUND
                    set_audio_status(Audio::Status::ON_SERVER)
                end
            end
            return audio_status == Audio::Status::ON_SERVER
        end

        def get_audio_file(network_task, tasks)
            # Try to find a local file if status is unknown
            setup_audio_file if audio.status == Audio::Status::UNKNOWN || audio.file.nil?

            # If status is on server, get the remote file.
            return get_remote_audio_file(network_task, tasks) if available_on_server?

            return audio.status
        end

        def get_remote_audio_file(network_task, tasks)
            if Cfg.remote?
                unless tasks.track_in_download?(self)
#                     tasks.new_track_download(emitter, self)
                    tasks.new_download(network_task)
                    set_audio_status(Audio::Status::ON_SERVER)
                end
            else
                set_audio_status(Audio::Status::NOT_FOUND)
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
                cover_file = Cfg.covers_dir+record.rrecord.to_s
                FileUtils::mkpath(cover_file)
                cover_file += File::SEPARATOR+track.rtrack.to_s+File::extname(fname)
                ex_name = cover_file+File::SEPARATOR+"ex"+track.rtrack.to_s+File::extname(fname)
            else
                # Assign file to record
                cover_file = Cfg.covers_dir+record.rrecord.to_s+File::extname(fname)
                ex_name = Cfg.covers_dir+"ex"+record.rrecord.to_s+File::extname(fname)
            end
            if File::exists?(cover_file)
                File::unlink(ex_name) if File::exists?(ex_name)
                FileUtils::mv(cover_file, ex_name)
            end
            #File::unlink(cover_file) if File::exists?(cover_file)
            FileUtils::mv(fname, cover_file)

            # Force the cache to reload new image
            load_record_cover(record.rrecord, record.irecsymlink, Image::Cache::LARGE_SIZE)

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
end
