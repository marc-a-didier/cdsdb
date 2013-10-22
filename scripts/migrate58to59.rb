#!/usr/bin/env ruby

#
# Migration from 5.8 cds db to 5.9
#
# Added irating and itags fields in artists & records
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

$src = SQLite3::Database.new(path+"cds5.8.db")
$src.execute("PRAGMA synchronous=OFF;")

$dst = SQLite3::Database.new(path+"cds5.9.db")
$dst.execute('PRAGMA synchronous=OFF;')
$dst.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    sql = ""
    IO.foreach("./sqlitecds5.9.sql") { |line| sql += line.chomp }
    $dst.execute_batch(sql)
end

def dup_table(table) # Copy table as it, that is there are no change
    $dst.execute("DELETE FROM #{table};")
    $dst.execute("BEGIN TRANSACTION;")
    $src.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{table} VALUES ("
        row.each { |val| sql += val.to_sql+"," }

#         sql += "0,0," if ["records", "artists"].include?(table)

        sql = sql[0..-2]+");"
puts sql
        $dst.execute(sql)
    end
    $dst.execute("COMMIT;")
end

["collections", "medias", "genres", "labels", "plists", "pltracks", "origins",
 "artists", "records", "segments", "tracks", "hostnames", "logtracks"].each { |table| dup_table(table) }

$dst.execute("INSERT INTO filters VALUES (0, 'Default filter', '<filter />');")
