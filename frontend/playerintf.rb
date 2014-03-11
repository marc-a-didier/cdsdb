
# This module defines all the methods that a player provider should respond to

module PlayerIntf

    # Emitted every half second for the provider do whatever it wants
    def timer_notification(ms_time)
        return self
    end

    # Called when a track has started playing
    def started_playing(player_data)
        return self
    end

    # Called when a track is finished.
    # message is the type of termination. may be :stop, :finish or :next
    def notify_played(player_data, message)
        return self
    end

    # Should append max_entries tracks to queue
    def prefetch_tracks(queue, max_entries)
        return self
    end

    # Called via master conntroller to get a track to play
    # direction may be :start, :next or :prev
    # :start is used to get the first track when the play button is pressed
    # :next is never used as the player has a prefetch queue
    # :prev is used to get the previous track
    def get_track(player_data, direction)
        return nil
    end

    # Should return true if provider has more tracks to play
    # direction is either :next or :prev
    # Should return true or false if it has or not a track in the wanted direction
    def has_track(player_data, direction)
        return false
    end
end