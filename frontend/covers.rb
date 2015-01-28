
module XIntf

    #
    # Module that handle search and caching of image for a track and/or record.
    # It feeds the XIntf::Image::Cache with asked for tracks/records and maintains
    # the TrackKeyCache hash to speed search for track covers.
    #
    module Covers

        def record_in_cache?(rrecord, irecsymlink)
            @pix_key = irecsymlink == 0 ? "r"+rrecord.to_s : "r"+irecsymlink.to_s
            return IMG_CACHE.has_key(@pix_key)
        end

        def get_cover_file_name
            files = Dir[CFG.covers_dir+@pix_key[1..-1]+".*"] # Skip 'r'.
            # TRACE.debug "CoverMgr search key #{@pix_key} - disk access".red
            return files.size > 0 ? File::basename(files[0]) : Image::Cache::DEF_RECORD_FILE
        end

        # @pix_key is set by record_in_cache? since we always check the hash before the file system
        def load_record_cover(rrecord, irecsymlink, size)
            file = get_cover_file_name
            if file == Image::Cache::DEF_RECORD_FILE
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
end