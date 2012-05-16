
class AudioDialog

    def initialize
        @glade = GTBld::load(UIConsts::AUDIO_DIALOG)
    end

    def show(file_name)
        tags = TagLib::File.new(file_name)

        @glade[UIConsts::AUDIO_ENTRY_FILE].text = file_name
        @glade[UIConsts::AUDIO_LBL_DTITLE].text = tags.title
        @glade[UIConsts::AUDIO_LBL_DARTIST].text = tags.artist
        @glade[UIConsts::AUDIO_LBL_DALBUM].text = tags.album
        @glade[UIConsts::AUDIO_LBL_DTRACK].text = tags.track.to_s
        @glade[UIConsts::AUDIO_LBL_DYEAR].text = tags.year.to_s
        @glade[UIConsts::AUDIO_LBL_DDURATION].text = Utils::format_ms_length(tags.length*1000)
        @glade[UIConsts::AUDIO_LBL_DGENRE].text = tags.genre
        @glade[UIConsts::AUDIO_ENTRY_COMMENT].text = tags.comment

        @glade[UIConsts::AUDIO_LBL_DCODEC].text = "???"
        @glade[UIConsts::AUDIO_LBL_DCHANNELS].text = tags.channels.to_s
        @glade[UIConsts::AUDIO_LBL_DSAMPLERATE].text = tags.samplerate.to_s+" Hz"
        @glade[UIConsts::AUDIO_LBL_DBITRATE].text = tags.bitrate.to_s+" Kbps"

        tags.close

        @glade[UIConsts::AUDIO_DIALOG].run
        @glade[UIConsts::AUDIO_DIALOG].destroy
    end

end
