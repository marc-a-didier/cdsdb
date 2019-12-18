
#
# The next classes handle the interactions with the UI by displaying
# information lines and the record/track image.
#
# Note that the image handling is performed by the track relevant class
# therefore both artist and record/segment only inherit from DBCacheLink
# since they do not need anything else than providing a text line.
#
#

module XIntf

    class Artist < DBCache::Link

        def to_widgets
            GtkUI[GtkIDs::MW_INFLBL_ARTIST].text = info_string
            GtkUI[GtkIDs::MEMO_ARTIST].buffer.text = valid_artist_ref? ? artist.mnotes.to_memo : ''
        end

        def from_widgets
            artist.mnotes = GtkUI[GtkIDs::MEMO_ARTIST].buffer.text.to_dbstring
            artist.sql_update
            return self
        end

        def info_string
            return '' if !valid_artist_ref? || artist.rorigin == 0
            return DBCache::Cache.origin(artist.rorigin).sname
        end
    end


    class Record < DBCache::Link

        def to_widgets(is_record)
            GtkUI[GtkIDs::MW_INFLBL_RECORD].text = is_record ? rec_info_string : seg_info_string
            GtkUI[GtkIDs::MEMO_RECORD].buffer.text  = valid_record_ref?  ? record.mnotes.to_memo  : ''
            GtkUI[GtkIDs::MEMO_SEGMENT].buffer.text = valid_segment_ref? ? segment.mnotes.to_memo : ''
            return self
        end

        def from_widgets
            record.mnotes = GtkUI[GtkIDs::MEMO_RECORD].buffer.text.to_dbstring
            record.sql_update
            segment.mnotes = GtkUI[GtkIDs::MEMO_SEGMENT].buffer.text.to_dbstring
            segment.sql_update
            return self
        end

        def rec_info_string
            return '' unless valid_record_ref?
            rec = DBCache::Cache.record(@rrecord) # Cache of the cache!!!
            str  = rec.itrackscount.to_s+' '+genre.sname+' track'.check_plural(rec.itrackscount)+' '
            str += DBCache::Cache.media(rec.rmedia).sname
            str += rec.iyear == 0 ? ', Unknown' : ', '+rec.iyear.to_s
            str += ', '+DBCache::Cache.label(record.rlabel).sname
            str += ', '+rec.scatalog unless rec.scatalog.empty?
            str += ', '+rec.isetorder.to_s+' of '+rec.isetof.to_s if rec.isetorder > 0
            str += ', '+DBCache::Cache.collection(rec.rcollection).sname if rec.rcollection != 0
            str += ', '+rec.iplaytime.to_ms_length
            str += ' [%.4f | %.4f]' % [rec.igain/Audio::GAIN_FACTOR, rec.ipeak/Audio::GAIN_FACTOR]
            return str
        end

        def seg_info_string
            return '' unless valid_segment_ref?
            str  = 'Segment '+segment.iorder.to_s
            str += ' '+segment.stitle unless segment.stitle.empty?
            str += ' by '+segment_artist.sname+' '+segment.iplaytime.to_ms_length
            return str
        end
    end


    class Track < XIntf::Link

        def to_widgets
            GtkUI[GtkIDs::MW_INFLBL_TRACK].text   = info_string
            GtkUI[GtkIDs::MEMO_TRACK].buffer.text = valid_track_ref? ? track.mnotes.to_memo : ''
            return self
        end

        # TODO: find a way to not redraw image each time if not changed
        def to_widgets_with_cover
            GtkUI[GtkIDs::REC_IMAGE].pixbuf = large_track_cover #if @pix_key.empty? || @curr_pix_key != @pix_key
            return to_widgets
        end

        def from_widgets
            track.mnotes = GtkUI[GtkIDs::MEMO_TRACK].buffer.text.to_dbstring
            track.sql_update
            return self
        end

        def info_string
            return '' unless valid_track_ref?
            trk = DBCache::Cache.track(@rtrack) # Cache of the cache!!!
            str  = Qualifiers::RATINGS[trk.irating]+', '
            str += trk.iplayed > 0 ? 'played '+trk.iplayed.to_s+' time'.check_plural(trk.iplayed)+' ' : 'never played, '
            str += '(Last: '+trk.ilastplayed.to_std_date+'), ' if trk.ilastplayed != 0
            if trk.itags == 0
                str += 'no tags '
            else
                str += 'tagged as '
                Qualifiers::TAGS.each_with_index { |tag, i| str += tag+' ' if (trk.itags & (1 << i)) != 0 }
            end
            str += '[%.4f | %.4f]' % [trk.igain/Audio::GAIN_FACTOR, trk.ipeak/Audio::GAIN_FACTOR]
            return str
        end
    end
end
