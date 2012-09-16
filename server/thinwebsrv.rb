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
require '../shared/dbutils'

Thread::abort_on_exception = true

GenreDBS = Struct.new(:rgenre, :sname)

class Navigator

    attr_accessor :genre, :artist, :record, :segment, :track

    def initialize
        @genre   = DBClassIntf.new(GenreDBS.new)
        @artist  = ArtistDBClass.new
        @record  = RecordDBClass.new
        @segment = SegmentDBClass.new
        @track   = TrackDBClass.new
    end

    def default_style
        %Q{<head><style type="text/css">
           a{font-family:Arial,Helvetica,sans-serif;}
           </style></head>}
    end

    def home_page
        page = default_style
        page += "<h1>Genres</h1><br><br><ul>"
        sql = "SELECT * FROM genres ORDER BY LOWER(sname)"
        DBIntf::connection.execute(sql) { |row|
            page += "<a href=/muse?genre=#{row[0]}>#{CGI::escapeHTML(row[1])}</a><br/>"
        }
        page += "</ul>"
        return page
    end

    def artists_by_genre(rgenre)
        @genre.ref_load(rgenre)

        page = default_style
        page += "<h1>Artists</h1><br><br><ul>"
        sql = %Q{SELECT DISTINCT(artists.rartist), artists.sname FROM artists
                    INNER JOIN segments ON segments.rartist = artists.rartist
                    INNER JOIN records ON records.rrecord = segments.rrecord
                    WHERE records.rgenre=#{rgenre} ORDER BY LOWER(artists.sname)}
        DBIntf::connection.execute(sql) { |row|
            page += "<a href=/muse?artist=#{row[0]}>#{CGI::escapeHTML(row[1])}</a><br>"
        }
        page += "</ul>"
        return page
    end

    def records_by_artist(rartist)
        @artist.ref_load(rartist)

        page = default_style
        page += %Q{<style type="text/css">p.ex1{font:15px arial,sans-serif;}</style>}

        page += %Q{<h1>Records</h1><br><br><table border="1">}
        sql = %Q{SELECT DISTINCT(rrecord) FROM segments WHERE rartist=#{rartist};}
        record = RecordDBClass.new
        DBIntf::connection.execute(sql) { |segment|
            record.ref_load(segment[0])
            image_file = Utils::get_cover_file_name(record.rrecord, 0, record.irecsymlink)
            image_file = Cfg::instance.covers_dir+"default.png" if image_file.empty?
            page += "<tr>"
            page += %Q{<td><img src="/image?ref=#{URI::escape(image_file)}" width="128" height="128" /></td>}
            page += "<td>"
            page += "<a href=/muse?record=#{record.rrecord}>#{CGI::escapeHTML(record.stitle)}</a>"
            page += %Q{<p class="ex1">Year: #{record.iyear}<br/>}
            page += %Q{Label: #{CGI::escapeHTML(DBUtils::name_from_id(record.rlabel, "label"))}<br/>}
            page += %Q{Catalog: #{record.scatalog}<br/>}
            page += %Q{Play time: #{Utils::format_ms_length(record.iplaytime)}}
            page += "</p>"
            page += "</td>"
            page += "</tr>"
        }
        page += "</table>"
        return page
    end

    def tracks_by_record(rrecord)
        page = default_style
        page += "<h1>Tracks</h1><br><br><ul>"
        sql = %Q{SELECT tracks.rtrack, tracks.iorder, segments.rrecord FROM tracks
                 INNER JOIN segments ON tracks.rsegment=segments.rsegment
                 WHERE segments.rrecord=#{rrecord} AND segments.rartist=#{@artist.rartist}
                 ORDER BY tracks.iorder}
        DBIntf::connection.execute(sql) { |row|
            @track.ref_load(row[0])
            page += "<a href=/muse?track=#{@track.rtrack}>#{@track.iorder} - #{CGI::escapeHTML(@track.stitle)}</a><br>"
        }
        page += "</ul>"
        return page
    end
end

class NavMgr < Navigator
    include Singleton
end

class ImageProvider
  def call(env)
    [ 200, { 'Content-Type' => 'image/jpeg' }, [File.read(Rack::Utils::parse_query(env["QUERY_STRING"])['ref'])] ]
  end
end

class SimpleAdapter
  def call(env)
p env
    params = Rack::Utils::parse_query(env["QUERY_STRING"])
p params
# p env["PATH_INFO"]

    ret_code = 200
    if params.empty?
        page = NavMgr::instance.home_page
    elsif params["genre"]
        page = NavMgr::instance.artists_by_genre(params["genre"])
    elsif params["artist"]
        page = NavMgr::instance.records_by_artist(params["artist"])
    elsif params["record"]
        page = NavMgr::instance.tracks_by_record(params["record"])
    else
        ret_code = 404
        page = "Fuck you up..."
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

# app = Rack::Directory.new(Cfg::instance.music_dir)
# Thin::Server.start('0.0.0.0', 7125, app)# do

Cfg::instance.load

Thin::Server.start('0.0.0.0', 7125) do
  use Rack::CommonLogger
  map '/muse' do
    run SimpleAdapter.new
  end
  map '/image' do
      run ImageProvider.new
  end
  map '/files' do
    run Rack::Directory.new(Cfg::instance.music_dir)
  end
end
