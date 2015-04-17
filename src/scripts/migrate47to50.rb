#!/usr/bin/env ruby

#
# Migration from 4.5 cds db to 4.6
#
# Exactly the same code as for 4.4 to 4.5, only idateripped field added to the records table
#
# Added idateadded in records
#
#

require 'sqlite3'
require 'arrayfields'

class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

NUM_TYPES = ["INTEGER", "SMALLINT"]

$db3 = SQLite3::Database.new("cds4.7.db")
$db3.execute("PRAGMA synchronous=OFF;")

$db4 = SQLite3::Database.new("cds5.0.db")
$db4.execute('PRAGMA synchronous=OFF;')
$db4.execute('PRAGMA encoding="UTF-8";')

if ARGV[0] == "--create"
    $sql = ""
    IO.foreach("sqlitecds5.0.sql") { |line| $sql += line.chomp }
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
        sql = sql[0..-2]+");"
puts sql
        $db4.execute(sql)
    end
    $db4.execute("COMMIT;")
end

def dup_table_as(table, as_table) # Copy table as it, that is there are no change
    $db4.execute("DELETE FROM #{as_table};")
    $db4.execute("BEGIN TRANSACTION;")
    $db3.execute("SELECT * FROM #{table}") do |row|
        sql = "INSERT INTO #{as_table} VALUES ("
        row.each_with_index do |val, i|
            NUM_TYPES.include?(row.types[i].upcase) ? sql += val+"," : sql += val.to_sql+","
        end
        sql = sql[0..-2]+");"
puts sql
        $db4.execute(sql)
    end
    $db4.execute("COMMIT;")
end

def set_start_to_zero(tbl)
    fld = "r"+tbl[0..-2]
    $db3.execute("UPDATE #{tbl} SET #{fld}=#{fld}-1")
    if tbl == "origins"
        $db3.execute("UPDATE artists SET #{fld}=#{fld}-1 WHERE #{fld}>0")
    else
        $db3.execute("UPDATE records SET #{fld}=#{fld}-1 WHERE #{fld}>0")
    end
end

set_start_to_zero("mediatypes")
set_start_to_zero("musictypes")
set_start_to_zero("collections")
set_start_to_zero("labels")
set_start_to_zero("origins")

dup_table_as("mediatypes", "medias")
dup_table_as("musictypes", "genres")

["collections", "labels", "plists", "pltracks", "logtracks", "origins"].each { |table| dup_table(table) }
["artists", "records", "segments", "tracks"].each { |table| dup_table(table) }
