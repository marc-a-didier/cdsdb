
require '../shared/audio'
require '../frontend/cddatafeeder'

feeder = CDDataFeeder.new
feeder.query_musicbrainz('/dev/sr0')
p feeder.disc
exit(0)

if feeder.load_cd_metadata('/dev/sr0')
    feeder.query_musicbrainz
    p feeder.disc
end
