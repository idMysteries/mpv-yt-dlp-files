local saved_time = 0.0
local total_saved_time = 0.0
local last_time_pos = nil
local last_speed = 1.0

local function update_saved_time()
    local current_time_pos = mp.get_property_number("time-pos", 0)
    local current_speed = mp.get_property_number("speed", 1.0)
    
    if last_time_pos and last_speed ~= 1.0 then
        local elapsed_time = current_time_pos - last_time_pos
        local effective_time = elapsed_time * (1.0 - 1.0 / last_speed)
        saved_time = saved_time + effective_time
        total_saved_time = total_saved_time + effective_time
    end
    
    last_time_pos = current_time_pos
    last_speed = current_speed
end

local function format_time(time)
    local hours = math.floor(time / 3600)
    local minutes = math.floor(time / 60) % 60
    local seconds = math.floor(time % 60)
    local milliseconds = math.floor(time * 1000) % 1000
    return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
end

local function show_saved_time()
    update_saved_time()
    local time_message = string.format("Current saved time: %s\nTotal saved time: %s", format_time(saved_time), format_time(total_saved_time))
    mp.osd_message(time_message, 2)
end

local function on_file_loaded()
    saved_time = 0.0
    last_time_pos = mp.get_property_number("time-pos", 0)
    last_speed = mp.get_property_number("speed", 1.0)
end

local function on_speed_change(name, value)
    update_saved_time()
end

mp.register_event("file-loaded", on_file_loaded)
mp.observe_property("speed", "number", on_speed_change)

mp.add_key_binding("Ctrl+N", "show-saved-time", show_saved_time)