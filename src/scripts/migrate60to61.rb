#!/usr/bin/env ruby

#
# Migration from 5.9 cds db to 6.0
#
# Added fmaxrms & fmaxpeak to tracks & records table
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


path = "../../db/"

$src = SQLite3::Database.new(path+"cds6.0.db")
$src.execute("PRAGMA synchronous=OFF;")

$dst = SQLite3::Database.new(path+"cds6.1.db")
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    sql = ""
    IO.foreach("./sqlitecds6.1.sql") { |line| sql += line.chomp }
    $dst.execute_batch(sql)
end

def dup_table(table) # Copy table as it, that is there are no change
    dest_tbl = table == "hostnames" ? "hosts" : table

    $dst.execute("DELETE FROM #{dest_tbl};")
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM #{table}") do |row|
        if table == "tracks" || table == "records"
            row[row.size-1] = (row[row.size-1]*10000.0).to_i
            row[row.size-2] = (row[row.size-2]*10000.0).to_i
        end

        sql = "INSERT INTO #{dest_tbl} VALUES ("
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
 "hostnames", "logtracks", "filters"].each { |table| dup_table(table) }
