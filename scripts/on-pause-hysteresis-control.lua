--[[
    On Pause Demuxer Hysteresis Control for mpv

    This script dynamically adjusts the demuxer hysteresis in mpv based on playback state.
    When the video is paused by the user, it sets the demuxer hysteresis to zero,
    allowing the cache to fill up more aggressively. When playback resumes, it
    restores the original hysteresis setting to balance between caching and resource usage.

    Key features:
    1. Detects user-initiated pauses (ignores initial load state)
    2. Temporarily disables demuxer hysteresis during pauses
    3. Forces a seek operation to trigger immediate cache filling
    4. Restores original settings on playback resume

    This approach allows for more efficient use of the cache, providing a buffer
    of content when paused without unnecessarily using resources during normal playback.
]]

local original_hysteresis = mp.get_property_number("demuxer-hysteresis-secs")
local was_paused = false

local function on_pause_change(_, value)
    if value and not was_paused then
        mp.set_property("demuxer-hysteresis-secs", 0)
        local time_pos = mp.get_property("time-pos")
        if time_pos then
            mp.add_timeout(0.1, function()
                mp.commandv("seek", time_pos, "absolute", "exact")
            end)
        end
        was_paused = true
    elseif not value and was_paused then
        mp.set_property_number("demuxer-hysteresis-secs", original_hysteresis)
        was_paused = false
    end
end

mp.observe_property("pause", "bool", on_pause_change)