
class CDDataFeeder

    attr_reader :disc

    TrackData = Struct.new(:track, :title, :segment, :artist, :length)
    DiscInfo  = Struct.new(:title, :artist, :genre, :year, :length, :label, :catalog, :medium, :cddbid, :tracks) do
        def reset
            self.size.times { |i| self[i] = '' }
            self.year = 0
            self.medium = Audio::MEDIA_CD
            self.cddbid = 0
            self.tracks = []
            return self
        end
    end

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

        @disc = DiscInfo.new.reset
        @disc.length = (@discmd.sectors/75.0*1000.0).to_i
        @disc.medium = Audio::MEDIA_CD
        @disc.cddbid = @discmd.freedb_id.to_i

        @discmd.tracks.each do |track|
            @disc.tracks << TrackData.new(track.number, nil, nil, nil, (track.sectors/75.0*1000.0).to_i)
        end
        return @disc
    end

    def query_musicbrainz(device = '/dev/cdrom')
        require 'open-uri'
        begin
            require 'musicbrainz'
            require 'nokogiri'
        rescue LoadError
            puts("At least one of musicbrainz/nokogiri gem is missing")
            return
        end

        load_cd_metadata(device) unless @disc

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
                @disc.title = table.css('td')[1].text.gsub(/’/, "'")
                @disc.artist = table.css('td')[2].text.gsub(/’/, "'")
                @disc.year = table.css('td')[4].text.split("-")[0].to_i
                @disc.label = table.css('td')[6].text.gsub(/’/, "'")
                @disc.catalog = table.css('td')[7].text.gsub(/’/, "'")
                if refs = table.css('a[href]')
                    rec_ref = refs[0].attributes['href'].value.split("/").last
                    MusicBrainz::Release.find(rec_ref).tracks.each_with_index do |track, i|
                        @disc.tracks[i].title = track.title.gsub(/’/, "'")
                        @disc.tracks[i].artist = track.respond_to?(:artist) ? track.artist.gsub(/’/, "'") : @disc.artist
                        @disc.tracks[i].segment = @disc.title
                    end
                else
                    Trace.debug("No link for release on MusicBrainz")
                end
            else
                Trace.debug("No matching CD on MusicBrainz")
            end
        else
            Trace.debug("Page not found on MusicBrainz")
        end
        return self
    end

    def query_freedb(device = "/dev/cdrom")
        begin
            require 'freedb'
        rescue LoadError
            puts("Gem ruby-freedb not found. Install it to make the damn thing work.")
            return
        end

        load_cd_metadata(device) unless @disc

        begin
            fdb = Freedb.new(device, false).fetch_net
            if fdb.results.size > 0
                fdb.get_result(0)

                @disc.title = fdb.title.force_encoding('iso-8859-1').encode('utf-8').gsub(/’/, "'")
                @disc.artist = fdb.artist.force_encoding('iso-8859-1').encode('utf-8').gsub(/’/, "'")
                @disc.year = fdb.year
                @disc.genre = fdb.category

                is_compile = @disc.artist.match(/various/i) != nil
                fdb.tracks.each { |track| is_compile &= track['title'].match(/.+\/.+/) } if is_compile

                fdb.tracks.each_with_index do |track, i|
                    title = track['title'].force_encoding('iso-8859-1').encode('utf-8').gsub(/’/, "'")
                    @disc.tracks[i].title = is_compile ? title.split('/')[1] : title
                    @disc.tracks[i].artist = is_compile ? title.split('/')[0].gsub(/’/, "'") : @disc.artist
                    @disc.tracks[i].segment = @disc.title
                end
            else
                Trace.debug("No results found on FreeDB")
            end
        rescue
        end
        return self
    end
end
