#!/usr/bin/env ruby

require 'sqlite3'
require 'psych'

require '../shared/extenders'
require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbclassintf'

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
