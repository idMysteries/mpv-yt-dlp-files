local saved_time = 0.0
local total_saved_time = 0.0
local last_real_time = mp.get_time()
local last_speed = 1.0
local is_paused = false

local function update_saved_time()
    local current_real_time = mp.get_time()
    local current_speed = mp.get_property_number("speed", 1.0)
    local delta_real = current_real_time - last_real_time
    
    if not is_paused and last_speed ~= 1.0 and last_speed > 0 then
        local effective_time = delta_real * (last_speed - 1)
        saved_time = saved_time + effective_time
        total_saved_time = total_saved_time + effective_time
    end
    
    last_real_time = current_real_time
    last_speed = current_speed
end

local function format_time(time)
    local total_seconds = math.abs(time)
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor(total_seconds / 60) % 60
    local seconds = math.floor(total_seconds % 60)
    local milliseconds = math.floor(total_seconds * 1000) % 1000
    return string.format("%s%02d:%02d:%02d.%03d", 
        time < 0 and "-" or "", hours, minutes, seconds, milliseconds)
end

local function on_seek()
    update_saved_time()
    -- Reset timer after seek to prevent counting seek time
    last_real_time = mp.get_time()
end

local function on_pause_change(name, value)
    is_paused = value
    update_saved_time()
end

local function on_speed_change(name, value)
    update_saved_time()
end

local function on_file_loaded()
    saved_time = 0.0
    last_real_time = mp.get_time()
    last_speed = mp.get_property_number("speed", 1.0)
    is_paused = mp.get_property_native("pause")
end

local function log_to_terminal()
    update_saved_time()
    mp.msg.info(string.format("Time saved for this session: %s", format_time(saved_time)))
    mp.msg.info(string.format("Total accumulated saved time: %s", format_time(total_saved_time)))
end

mp.register_event("file-loaded", on_file_loaded)
mp.register_event("end-file", log_to_terminal)
mp.register_event("seek", on_seek)
mp.observe_property("speed", "number", on_speed_change)
mp.observe_property("pause", "bool", on_pause_change)

local function show_saved_time()
    update_saved_time()
    local time_message = string.format("Current saved time: %s\nTotal saved time: %s", 
        format_time(saved_time), format_time(total_saved_time))
    mp.osd_message(time_message, 2)
end

mp.add_key_binding("Ctrl+N", "show-saved-time", show_saved_time)
