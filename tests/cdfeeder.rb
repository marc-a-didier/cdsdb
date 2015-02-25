
require '../shared/audio'
require '../frontend/cddatafeeder'

feeder = CDDataFeeder.new
if feeder.load_cd_metadata('/dev/sr0')
    feeder.query_musicbrainz
    p feeder.disc
end
