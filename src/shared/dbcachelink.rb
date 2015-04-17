
module DBCache

    #
    # This class keeps references to the primary key of its tables and makes
    # load on demand into the cache.
    #
    class Link

        def initialize
            reset
        end

        def reset
            @rtrack   = nil
            @rsegment = nil
            @rrecord  = nil
            @rartist  = nil # Consider it's the SEGMENT artist
            @rgenre   = nil

            return self
        end


        #
        # Methods that load the row from the primary key
        # First search in cache and load from db if not found
        #
        # Tries to feed the artist primary key from record or segment if possible
        #
        def track
            return @rtrack ? DBCache::Cache.track(@rtrack) : nil
        end

        def segment
            if @rsegment.nil?
                if track
                    @rsegment = track.rsegment
                else
                    return nil
                end
            end
            return DBCache::Cache.segment(@rsegment)
        end

        def record
            if @rrecord.nil?
                if track
                    @rrecord = track.rrecord
                else
                    if segment
                        @rrecord = segment.rrecord
                    else
                        return nil
                    end
                end
            end
            return DBCache::Cache.record(@rrecord)
        end

        def artist
            if @rartist.nil?
                segment_artist
                record_artist unless @rartist
                return nil unless @rartist
            end
            return DBCache::Cache.artist(@rartist)
        end

        def segment_artist
            if segment
                @rartist = segment.rartist
            else
                return nil unless @rartist
            end
            return DBCache::Cache.artist(@rartist)
        end

        def record_artist
            if record
                @rartist = record.rartist
            else
                return nil unless @rartist
            end
            return DBCache::Cache.artist(@rartist)
        end

        def genre
            if record
                @rgenre = record.rgenre
            else
                return nil unless @rgenre
            end
            return DBCache::Cache.genre(@rgenre)
        end

        def set_audio_file(file_name)
            DBCache::Cache.set_audio_file(@rtrack, file_name)
            return self
        end

        def set_audio_status(status)
            DBCache::Cache.set_audio_status(@rtrack, status)
            return self
        end

        def set_audio_state(status, file)
            self.set_audio_status(status).set_audio_file(file)
        end

        def audio_status
            return DBCache::Cache.audio_status(@rtrack)
        end

        def audio_file
            return DBCache::Cache.audio(@rtrack).file
        end

        def audio
            return DBCache::Cache.audio(@rtrack)
        end

        def reset_audio
            DBCache::Cache.reset_audio(@rtrack)
            return self
        end


        #
        # Methods to check if a reference has been set for the cache to get it
        # May be used as bool func since nil or false behave the same
        #
        def valid_track_ref?
            return @rtrack
        end

        def valid_segment_ref?
            return @rsegment
        end

        def valid_record_ref?
            return @rrecord
        end

        def valid_artist_ref?
            return @rartist
        end


        #
        # These methods just set the primary key for futur use but DO NOT load the row
        #
        def set_track_ref(rtrack)
            @rtrack = rtrack
            return self
        end

        def set_segment_ref(rsegment)
            @rsegment = rsegment
            return self
        end

        def set_record_ref(rrecord)
            @rrecord = rrecord
            return self
        end

        def set_artist_ref(rartist)
            @rartist = rartist
            return self
        end

        def set_genre_ref(rgenre)
            @rgenre = rgenre
            return self
        end


        #
        # Methods to keep the cache in sync with the db in case of modifications
        #
        def reload_track_cache
            DBCache::Cache.track(@rtrack).sql_load
            return self
        end

        def reload_record_cache
            DBCache::Cache.record(@rrecord).sql_load
            return self
        end

        def reload_segment_cache
            DBCache::Cache.segment(@rsegment).sql_load
            return self
        end

        def reload_artist_cache
            DBCache::Cache.artist(@rartist).sql_load
            return self
        end

        def flush_main_tables
            DBCache::Cache.artist(@rartist).sql_update if valid_artist_ref?
            DBCache::Cache.record(@rrecord).sql_update if valid_record_ref?
            DBCache::Cache.segment(@rsegment).sql_update if valid_segment_ref?
            DBCache::Cache.track(@rtrack).sql_update if valid_track_ref?

            # [DBCache::Cache.track(@rtrack), DBCache::Cache.record(@rrecord),
            #  DBCache::Cache.segment(@rsegment), DBCache::Cache.artist(@rartist)].each { |dbclass| dbclass.sql_update }
        end
    end
end
