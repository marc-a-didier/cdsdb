
class AudioDialog

    def initialize
        GtkUI.load_window(GtkIDs::AUDIO_DIALOG)
    end

    def show(file_name)
        tags = TagLib::File.new(file_name)
        GtkUI[GtkIDs::AUDIO_ENTRY_FILE].text = file_name
        GtkUI[GtkIDs::AUDIO_LBL_DFILESIZE].text = File.size(file_name).to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1\'")+" bytes"
        GtkUI[GtkIDs::AUDIO_LBL_DTITLE].text = tags.title
        GtkUI[GtkIDs::AUDIO_LBL_DARTIST].text = tags.artist
        GtkUI[GtkIDs::AUDIO_LBL_DALBUM].text = tags.album
        GtkUI[GtkIDs::AUDIO_LBL_DTRACK].text = tags.track.to_s
        GtkUI[GtkIDs::AUDIO_LBL_DYEAR].text = tags.year.to_s
        GtkUI[GtkIDs::AUDIO_LBL_DDURATION].text = (tags.length*1000).to_ms_length
        GtkUI[GtkIDs::AUDIO_LBL_DGENRE].text = tags.genre
        GtkUI[GtkIDs::AUDIO_ENTRY_COMMENT].text = tags.comment

        GtkUI[GtkIDs::AUDIO_LBL_DCODEC].text = "???"
        GtkUI[GtkIDs::AUDIO_LBL_DCHANNELS].text = tags.channels.to_s
        GtkUI[GtkIDs::AUDIO_LBL_DSAMPLERATE].text = tags.samplerate.to_s+" Hz"
        GtkUI[GtkIDs::AUDIO_LBL_DBITRATE].text = tags.bitrate.to_s+" Kbps"

        tags.close

        GtkUI[GtkIDs::AUDIO_DIALOG].run
        GtkUI[GtkIDs::AUDIO_DIALOG].destroy
    end

end
