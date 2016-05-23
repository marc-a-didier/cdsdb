#!/usr/bin/env ruby

require 'sqlite3'
require 'fileutils'
require '../shared/extenders'

version = '6.2'
path = "../../db/"

dest = path+"cds#{version}.compacted.db"

$src = SQLite3::Database.new(path+"cds#{version}.db")
$src.execute("PRAGMA synchronous=OFF;")

FileUtils.rm(dest) if File.exists?(dest)
$dst = SQLite3::Database.new(dest)
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

sql = ""
IO.foreach("./sqlitecds#{version}.sql") { |line| sql += line.chomp }
$dst.execute_batch(sql)

def dup_table(table) # Copy table as it, that is there are no change
    $dst.execute("DELETE FROM #{table};")
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{table} VALUES ("
        row.each { |val| sql += val.to_sql+"," }

        sql = sql[0..-2]+");"
puts sql
        $dst.execute(sql)
    end
    $dst.execute("COMMIT;")
end

["collections", "medias", "genres", "labels",
 "plists", "pltracks", "origins",
 "artists", "records", "segments", "tracks",
 "hosts", "logtracks", "filters"].each { |table| dup_table(table) }
