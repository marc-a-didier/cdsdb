
class CDDataFeeder

    attr_reader :disc

    TrackData = Struct.new(:track, :title, :segment, :artist, :length)
    DiscInfo  = Struct.new(:title, :artist, :genre, :year, :length, :label, :catalog, :medium, :cddbid, :tracks)

    def initialize
        begin
            require 'discid'
        rescue LoadError
            puts("Gem discid not found. Install it to make the damn thing work.")
        end

        @disc = nil
        @discmd = nil
    end

    def load_cd_metadata(device = '/dev/cdrom')
        begin
            @discmd = DiscId.read(device, :isrc, :mcn)
        rescue DiscId::DiscError => e
            puts e
            return nil
        end

        @disc = DiscInfo.new
        @disc.length = (@discmd.sectors/75.0*1000.0).to_i
        @disc.medium = Audio::MEDIA_CD
        @disc.cddbid = @discmd.freedb_id.to_i

        @disc.tracks = []
        @discmd.tracks.each do |track|
            @disc.tracks << TrackData.new(track.number, nil, nil, nil, (track.sectors/75.0*1000.0).to_i)
        end
        return @disc
    end

    def query_musicbrainz
        require 'open-uri'
        begin
            require 'musicbrainz'
            require 'nokogiri'
        rescue LoadError
            puts("At least one of musicbrainz/nokogiri gem is missing")
        end

        load_cd_metadata unless @disc

        MusicBrainz.configure do |c|
            # Application identity (required)
            c.app_name = "CDsDB"
            c.app_version = "0.9.5"
            c.contact = "support@nowhere.com"

            # Cache config (optional)
            c.cache_path = "/tmp/musicbrainz-cache"
            c.perform_caching = true

            # Querying config (optional)
            #   c.query_interval = 1.2 # seconds
            #   c.tries_limit = 2
        end

        page = Nokogiri::HTML(open(@discmd.submission_url))
        if page
            found = page.css('h2') && page.css('h2').text == "Matching CDs"
            if found && page.css('table')
                table = page.css('table')
                @disc.title = table.css('td')[1].text
                @disc.artist = table.css('td')[2].text
                @disc.year = table.css('td')[4].text.split("-")[0].to_i
                @disc.label = table.css('td')[6].text
                @disc.catalog = table.css('td')[7].text
                if refs = table.css('a[href]')
                    rec_ref = refs[0].attributes['href'].value.split("/").last
                    MusicBrainz::Release.find(rec_ref).tracks.each_with_index do |track, i|
                        @disc.tracks[i].title = track.title
                        @disc.tracks[i].artist = track.respond_to?(:artist) ? track.artist : @disc.artist
                        @disc.tracks[i].segment = @disc.title
                    end
                end
            end
        end
    end
end
