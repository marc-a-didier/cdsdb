#!/usr/bin/ruby

require 'sqlite3'

$db = SQLite3::Database.new("cds5.7.new.db")
$db.execute('PRAGMA synchronous=OFF;')
$db.execute('PRAGMA encoding="UTF-8";')

$sql = ""
IO.foreach("sqlitecds5.7.sql") { |line| $sql += line.chomp }
$db.execute_batch($sql)

IO.foreach("reorder.sql") { |line| $db.execute(line) if line.size > 1 }
