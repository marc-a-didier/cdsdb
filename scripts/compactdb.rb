#!/usr/bin/env ruby

#
# Unload/reload database -> compact it
#

require 'sqlite3'
require 'arrayfields'

class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end
end

NUM_TYPES = ["INTEGER", "SMALLINT"]

$db3 = SQLite3::Database.new("cds5.2.db")
$db3.execute("PRAGMA synchronous=OFF;")

$db4 = SQLite3::Database.new("cds5.2.new.db")
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

["medias", "collections", "labels", "genres", "plists", "pltracks", "logtracks", "origins"].each { |table| dup_table(table) }
["artists", "records", "segments", "tracks"].each { |table| dup_table(table) }
