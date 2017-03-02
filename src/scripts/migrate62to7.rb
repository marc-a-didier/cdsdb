#!/usr/bin/env ruby

#
# Migration from 6.2 cds db to 7
#
# No mods, new db version table executed in the sqlite6.3.sql ddl
#
#

require 'sqlite3'

class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

class Integer
    alias :to_sql :to_s
end


path = "../../db/"

$src = SQLite3::Database.new(path+"cds6.2.db")
$src.execute("PRAGMA synchronous=OFF;")

$dst = SQLite3::Database.new(path+"cds.db")
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    sql = ""
    IO.foreach("./sqlitecds7.sql") { |line| sql += line.chomp }
    $dst.execute_batch(sql)
end

def dup_table(table) # Copy table as it, that is there are no change
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{table} VALUES ("+row.map { |val| val.to_sql }.join(',')+')'
puts sql
        $dst.execute(sql)
    end
    $dst.execute("COMMIT;")
end

["collections", "medias", "genres", "labels",
 "plists", "pltracks", "origins",
 "artists", "records", "segments", "tracks",
 "hosts", "logtracks", "filters"].each { |table| dup_table(table) }
