#!/usr/bin/env ruby

require 'singleton'
require 'fileutils'
require 'yaml'
require 'sqlite3'
require 'logger'
require 'rexml/document'

require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbclassintf'
require '../shared/dbcachemgr'
require '../shared/utils'
require '../shared/dbutils'
require '../shared/trackinfos'
require '../shared/audiolink'

require '../frontend/cdeditorwindow'
require '../frontend/discanalyzer'

disc = CDEditorWindow::DiscInfo.new
f = File.open(Cfg.rsrc_dir+'testanalyzer.sql', "w")

disc.title = "Disc standard"
disc.artist = "Artist standard"
disc.genre = "Punk"
disc.label = "Fat Wreck Chords"
disc.catalog = "FAT 0007"
disc.year = 2020
disc.length = 123456
disc.cddbid = 0x00001
disc.medium = Audio::MEDIA_CD
disc.tracks = []
10.times { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", disc.title, disc.artist, 10000) }
DiscAnalyzer.analyze(disc, f)
f.puts

disc.title = "Disc with segments"
disc.artist = "Artist standard"
disc.genre = "disc.md.genre"
disc.label = "Fat Wreck"
disc.catalog = "FAT 0008"
disc.year = 2025
disc.length = 234567
disc.cddbid = 0x00002
disc.medium = Audio::MEDIA_CD
disc.tracks = []
(1..4).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 1", disc.artist, 10000) }
(5..8).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 2", disc.artist, 10000) }
DiscAnalyzer.analyze(disc, f)
f.puts

disc.title = "Compilation disc"
disc.artist = "Compilation"
disc.genre = "disc.md.genre"
disc.label = "Fat Wreck"
disc.catalog = "FAT 0009"
disc.year = 2026
disc.length = 345678
disc.cddbid = 0x00002
disc.medium = Audio::MEDIA_CD
disc.tracks = []
(1..2).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", disc.title, "artist 1", 10000) }
(3..4).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", disc.title, "artist 2", 10000) }
(5..6).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", disc.title, "artist 3", 10000) }
(7..8).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", disc.title, "artist 1", 10000) }
DiscAnalyzer.analyze(disc, f)
f.puts


disc.title = "Compilation disc with segments"
disc.artist = "Compilation"
disc.genre = "disc.md.genre"
disc.label = "Fat Wreck Chords"
disc.catalog = "FAT 0010"
disc.year = 2027
disc.length = 456789
disc.cddbid = 0x00002
disc.medium = Audio::MEDIA_CD
disc.tracks = []
(1..2).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 1", "artist 1", 10000) }
(3..4).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 2", "artist 2", 10000) }
(5..6).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 3", "artist 3", 10000) }
(7..8).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment 4", "artist 1", 10000) }
DiscAnalyzer.analyze(disc, f)
f.puts

disc.title = "Standard disc with segment name other than disc title"
disc.artist = "nofx"
disc.genre = "disc.md.genre"
disc.label = "Fat Wreck Chords"
disc.catalog = "FAT 0011"
disc.year = 2028
disc.length = 456789
disc.cddbid = 0x00002
disc.medium = Audio::MEDIA_CD
disc.tracks = []
(1..6).each { |i| disc.tracks << CDEditorWindow::TrackData.new(i, "title #{i}", "segment title", disc.artist, 10000) }
DiscAnalyzer.analyze(disc, f)
f.puts

f.close
