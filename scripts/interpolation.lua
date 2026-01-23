local mp = require 'mp'

local FPS_INTERP_LIMIT = 30.5
local CADENCE_EPS = 0.01

local function is_integer_multiple(display_fps, video_fps)
    local ratio = display_fps / video_fps
    local nearest = math.floor(ratio + 0.5)
    return math.abs(ratio - nearest) < CADENCE_EPS
end

local function apply()
    local video_fps = mp.get_property_number("container-fps")
    if not video_fps then
        video_fps = mp.get_property_number("estimated-vf-fps")
    end

    local display_fps = mp.get_property_number("display-fps")

    if not video_fps or not display_fps then
        print("[interp] FPS info unavailable")
        return
    end

    local cadence_ok = is_integer_multiple(display_fps, video_fps)

    if video_fps <= FPS_INTERP_LIMIT then
        if cadence_ok then
            mp.set_property("interpolation", "no")
            mp.set_property("video-sync", "audio")
            print(string.format(
                "[interp] %.3f fps on %.3f Hz: cadence OK -> no interpolation",
                video_fps, display_fps))
        else
            mp.set_property("interpolation", "yes")
            mp.set_property("video-sync", "display-resample")
            print(string.format(
                "[interp] %.3f fps on %.3f Hz: cadence BAD -> interpolation + resample",
                video_fps, display_fps))
        end
    else
        mp.set_property("interpolation", "no")
        if cadence_ok then
            mp.set_property("video-sync", "audio")
            print(string.format(
                "[interp] %.3f fps on %.3f Hz: high fps, cadence OK -> audio sync",
                video_fps, display_fps))
        else
            mp.set_property("video-sync", "display-resample")
            print(string.format(
                "[interp] %.3f fps on %.3f Hz: high fps, cadence BAD -> resample only",
                video_fps, display_fps))
        end
    end
end

mp.register_event("file-loaded", function()
    mp.add_timeout(0.1, apply)
end)

print("[interp] display-fps aware script loaded")