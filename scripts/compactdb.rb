#!/usr/bin/env ruby

#
#

require 'sqlite3'
require 'fileutils'


class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

class Fixnum
    def to_sql
        return self.to_s
    end
end

class Float
    def to_sql
        return self.to_s
    end
end


path = "../../db/"

dest = path+"cds6.1.compacted.db"

$src = SQLite3::Database.new(path+"cds6.1.db")
$src.execute("PRAGMA synchronous=OFF;")

FileUtils.rm(dest) if File.exists?(dest)
$dst = SQLite3::Database.new(dest)
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

sql = ""
IO.foreach("./sqlitecds6.1.sql") { |line| sql += line.chomp }
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
