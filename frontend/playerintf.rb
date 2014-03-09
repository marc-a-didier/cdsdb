
# This module defines all the methods that a player provider should respond to

module PlayerIntf

    # Emitted every half second for the provider do whatever it wants
    def timer_notification(ms_time)
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

    # Should return true if provider has more tracks to play
    # direction is either :next or :prev
    # Should return true or false if it has or not a track in the wanted direction
    def has_track(direction)
        return false
    end

    # Called via the master controller when it needs the first track to play
    # Master controller is called from the player when starting play or
    # when getting the previous as it invalidates the prefetch queue.
    # Should return a PlayerData class
    def get_next_track
        return nil
    end

    # Received when previous track is to be played
    # Should return a PlayerData class
    def get_prev_track
        return nil
    end
end