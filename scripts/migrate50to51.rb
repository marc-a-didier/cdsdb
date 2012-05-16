#!/usr/bin/env ruby

#
# Migration from 4.7 cds db to 5.0
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

$db3 = SQLite3::Database.new("cds5.0.db")
$db3.execute("PRAGMA synchronous=OFF;")

$db4 = SQLite3::Database.new("cds5.1.db")
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
        if table == "records"
            has_segs = false
            count = $db3.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rrecord=#{row[0]};").to_i
            if count > 1
                $db3.execute("SELECT stitle FROM segments WHERE rrecord=#{row[0]};") do |title|
                    if title[0] != row[3]
                        has_segs = true;
                        break
                    end
                end
            end
            has_segs ? sql += "1," : sql += "0,"
        end
        sql = sql[0..-2]+");"
puts sql
        $db4.execute(sql)
    end
    $db4.execute("COMMIT;")
end

["collections", "medias", "genres", "labels", "plists", "pltracks", "logtracks", "origins"].each { |table| dup_table(table) }
["artists", "records", "segments", "tracks"].each { |table| dup_table(table) }
