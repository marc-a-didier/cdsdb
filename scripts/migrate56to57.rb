#!/usr/bin/env ruby

#
# Migration from 5.6 cds db to 5.7
#
# Added iislocal in plists
#
#

require 'sqlite3'
#require 'arrayfields'

class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

NUM_TYPES = ["INTEGER", "SMALLINT"]

path = "../../db/"

$db3 = SQLite3::Database.new(path+"cds5.6.db")
$db3.execute("PRAGMA synchronous=OFF;")

$db4 = SQLite3::Database.new(path+"cds5.7.db")
$db4.execute('PRAGMA synchronous=OFF;')
$db4.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    $sql = ""
    IO.foreach("./sqlitecds5.7.sql") { |line| $sql += line.chomp }
    $db4.execute_batch($sql)
end

def dup_table(table) # Copy table as it, that is there are no change
    $db4.execute("DELETE FROM #{table};")
    $db4.execute("BEGIN TRANSACTION;")
    $db3.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{table} VALUES ("
        row.each_with_index do |val, i|
            NUM_TYPES.include?(row.types[i].upcase) ? sql += val+"," : sql += val.to_sql+","
        end
        sql += "0, 0, 0," if table == "plists" # local, created, modified
        sql += "0," if table == "tracks" # pref order
        sql = sql[0..-2]+");"
puts sql
        $db4.execute(sql)
    end
    $db4.execute("COMMIT;")
end

["collections", "medias", "genres", "labels", "plists", "pltracks", "logtracks", "origins"].each { |table| dup_table(table) }
["artists", "records", "segments", "tracks"].each { |table| dup_table(table) }
