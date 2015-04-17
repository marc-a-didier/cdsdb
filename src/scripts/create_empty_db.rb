#!/usr/bin/env ruby

require 'sqlite3'

db = SQLite3::Database.new("./cds5.8.db")
db.execute('PRAGMA encoding="UTF-8";')

sql = ""
IO.foreach("./sqlitecds5.8.sql") { |line| sql += line.chomp }
db.execute_batch(sql)
