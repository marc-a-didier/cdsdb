#!/usr/bin/env ruby

require 'sqlite3'
require 'psych'

require '../shared/extenders'
require '../shared/cfg'
require '../shared/tracelog'
require '../shared/dbintf'
require '../shared/dbclassintf'
require '../shared/audio'
require '../shared/dbcache'
require '../shared/dbcachelink'
require '../shared/audiofilemgr'

dblink = DBCache::Link.new
dblink.set_artist_ref(11)
# dblink.artist.sname = "60 times the pain"

dblink.set_record_ref(2077)
# dblink.record.stitle = 'muse for punks'
dblink.record.rgenre = 1

# dblink.set_segment_ref(5998)
# dblink.segment.stitle = "total bronx"

# dblink.set_track_ref(26869)
# dblink.track.stitle = 'AGAINST ALL!!!'
# dblink.track.iorder = 99

# Audio::FileHandler.new([11, 2077, nil, nil], dblink).check_changes
Audio::FileHandler.new([11, 2077, nil, nil], dblink).check_changes

exit(0)

track = DBClasses::Track.new.ref_load(26952)
Audio::File.new.init_from_object(track).list

exit(0)



artist = DBClasses::Artist.new.ref_load(451)
genre = DBClasses::Genre.new
artist.each_record do |record|
    puts(record.stitle)
    genre.ref_load(record.rgenre)
    record.each_segment do |segment|
        puts("  Seg name: '#{segment.stitle}'")
        segment.each_track do |track|
            puts("    #{track.build_audio_file_name(artist, record, segment, genre)}")
#             puts("    #{track.iorder} - #{track.stitle}")
        end
        puts
    end
    puts
end
