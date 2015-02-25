
# A name space for audio files status

module Audio

    Tags = Struct.new(:artist, :album, :title, :track, :length, :year, :genre, :file_name)

    # The order matters if the same track is ripped in various format, prefered format first
    FILE_EXTS_BY_QUALITY = [".flac", ".ogg", ".mp3"]
    FILE_EXTS_BY_SIZE = [".ogg", ".mp3", ".flac"]

    MEDIA_CD   = 0
    MEDIA_FILE = 5

    module Status
        NOT_FOUND = 0 # Local audio file not found and/or not on server
        OK        = 1 # Local audio file found where expected to be
        MISPLACED = 2 # Local audio file found but NOT where it should be
        ON_SERVER = 3 # No local file but available from server
        UNKNOWN   = 4 # Should be default value, no check has been made
    end

    GAIN_FACTOR = 10000.0
end
