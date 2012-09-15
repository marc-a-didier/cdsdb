#!/usr/bin/env ruby

require 'thin'

require 'cgi'

require 'sqlite3'

require 'singleton'
require 'rexml/document'

require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbutils'
require '../shared/dbclassintf'
require '../shared/utils'
require '../shared/uiconsts'

Thread::abort_on_exception = true

class PageBuilder

    def self.genres
        page = %Q{<head><style type="text/css">
                  a{font-family:Arial,Helvetica,sans-serif;}
                  </style></head>}

        page += "<h1>Genres</h1><br><br><ul>"
        sql = "SELECT * FROM genres ORDER BY LOWER(sname)"
        DBIntf::connection.execute(sql) { |row|
#             page += "<a href=/test?genre=#{URI::escape(row[1])}>#{CGI::escapeHTML(row[1])}</a><br>"
            page += "<a href=/test?genre=#{row[0]}>#{CGI::escapeHTML(row[1])}</a><br/>"
        }
        page += "</ul>"
        return page
    end

    def self.artists_by_genre(rgenre)
        page = "<h1>Artists</h1><br><br><ul>"
        sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                    INNER JOIN segments ON segments.rartist = artists.rartist
                    INNER JOIN records ON records.rrecord = segments.rrecord
                    WHERE records.rgenre=#{rgenre} ORDER BY LOWER(artists.sname)}
        DBIntf::connection.execute(sql) { |row|
            page += "<a href=/test?artist=#{row[0]}&agenre=#{rgenre}>#{CGI::escapeHTML(row[1])}</a><br>"
        }
        page += "</ul>"
        return page
    end

    def self.records_by_artist_and_genre(rartist, rgenre)
        page = "<h1>Records</h1><br><br><ul>"
        sql = %Q{SELECT DISTINCT(rrecord) FROM segments WHERE rartist=#{rartist};}
        record = RecordDBClass.new
        DBIntf::connection.execute(sql) { |segment|
            record.ref_load(segment[0])
            image_file = Utils::get_cover_file_name(record.rrecord, 0, record.irecsymlink)
            image_file = Cfg::instance.covers_dir+"default.png" if image_file.empty?
#             page += %Q{<img src=#{URI::escape("file://"+image_file)} width="128" height="128" />}
            page += %Q{<img src="/image?ref=#{image_file}" width="128" height="128" />}
            page += "<a href=/test?record=#{record.rrecord}>#{CGI::escapeHTML(record.stitle)}</a><br>"
        }
        page += "</ul>"
        return page
    end

    def self.tracks_by_record(rsegment)
        page = "<h1>Tracks</h1><br><br><ul>"
        sql = "SELECT * FROM tracks WHERE rsegment=#{rsegment} ORDER BY iorder"
        DBIntf::connection.execute(sql) { |row|
            page += "<a href=/test?track=#{row[0]}>#{row[3]} - #{CGI::escapeHTML(row[5])}</a><br>"
        }
        page += "</ul>"
        return page
    end

end

class ImageProvider
  def call(env)
    params = CGI::parse(env["QUERY_STRING"])

    image = ""
    File.open(params['ref'][0], "rb") { |file| image = file.read }

    [ 200, { 'Content-Type' => 'image/jpeg' }, [image] ]
  end
end

class SimpleAdapter
  def call(env)
    params = CGI::parse(env["QUERY_STRING"])
p params

    ret_code = 200
    if params.empty?
        page = PageBuilder::genres
    elsif !params["genre"].empty?
        page = PageBuilder::artists_by_genre(params["genre"][0])
    elsif !params["artist"].empty?
        page = PageBuilder::records_by_artist_and_genre(params["artist"][0], params["agenre"][0])
    elsif !params["record"].empty?
        page = PageBuilder::tracks_by_record(params["record"][0])
    else
        ret_code = 404
        page = "Sorry guy..."
    end
    body = [page]

    [
      ret_code,
      { 'Content-Type' => 'text/html; charset=utf-8',
        'Title' => 'Test Muse' },
      body
    ]
  end
end

# app = Rack::Directory.new('/home/madmac/Music')
# Thin::Server.start('0.0.0.0', 7125, app)# do

Cfg::instance.load

Thin::Server.start('0.0.0.0', 7125) do
  use Rack::CommonLogger
  map '/test' do
    run SimpleAdapter.new
  end
  map '/image' do
      run ImageProvider.new
  end
  map '/files' do
    run Rack::Directory.new('/home/madmac/Music')
  end
end
