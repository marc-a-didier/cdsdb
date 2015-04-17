#!/usr/bin/env ruby

#
# Migration from 5.7 cds db to 5.8
#
# Added index on rtrack & idateplayed in logtracks
# Removed ipreforder in tracks
#
#

require 'sqlite3'

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


# NUM_TYPES = ["INTEGER", "SMALLINT"]

path = "../../db/"

$src = SQLite3::Database.new(path+"cds5.7.db")
$src.execute("PRAGMA synchronous=OFF;")

$dst = SQLite3::Database.new(path+"cds5.8.db")
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    sql = ""
    IO.foreach("./sqlitecds5.8.sql") { |line| sql += line.chomp }
    $dst.execute_batch(sql)
end

def dup_table(table) # Copy table as it, that is there are no change
    $dst.execute("DELETE FROM #{table};")
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{table} VALUES ("
        row.slice!(-1) if table == "tracks" # Remove last element
        if table == "records"
            # Must remove cols 4 & 11. Beware to the order. if 4 is removed before, 11 becomes 10.
            row.slice!(11)
            row.slice!(4)
        end
        row.each { |val| sql += val.to_sql+"," }
        sql = sql[0..-2]+");"
puts sql
        $dst.execute(sql)
    end
    $dst.execute("COMMIT;")
end

def migrate_log
    # Fill hostnames table and save an array of the names to speed up things...
    hostnames = []
    rhostname = 1
    $dst.execute("BEGIN TRANSACTION;")
    $dst.execute("INSERT INTO hostnames VALUES (0, 'localhost')")
    $src.execute("SELECT DISTINCT(shostname) FROM logtracks") { |row|
        sql = "INSERT INTO hostnames VALUES (#{rhostname}, #{row[0].to_sql})"
puts sql                                                              
        $dst.execute(sql)
        hostnames << row[0]
        rhostname += 1
    }
    $dst.execute("COMMIT;")

    $dst.execute("DELETE FROM logtracks;")
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM logtracks") do |row|
        sql = "INSERT INTO logtracks VALUES (#{row[1]}, #{row[2]}, #{hostnames.index(row[3])+1});"
puts sql        
        $dst.execute(sql)
    end
    $dst.execute("COMMIT;")
end

["collections", "medias", "genres", "labels", "plists", "pltracks", "origins"].each { |table| dup_table(table) }
["artists", "records", "segments", "tracks"].each { |table| dup_table(table) }
migrate_log
