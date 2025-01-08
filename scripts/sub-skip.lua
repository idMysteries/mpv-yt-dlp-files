local prev_speed = 1.0
local fast_speed = 1.75

local patterns_list = {
    '♬', '～♬', '♬～', '♫', '～♫', '♫～', '☎', '♪', '♪～', '～♪', '🎶', '#', '♯', '♩♪', '🎵'
}

local patterns = {}
for _, pattern in ipairs(patterns_list) do
    patterns[pattern] = true
end

local script_enabled = false

local function adjust_speed(_, sub_text)
    if not sub_text or sub_text == "" or patterns[sub_text] then
        prev_speed = mp.get_property_number("speed", 1.0)
        mp.set_property("speed", fast_speed)
    else
        mp.set_property("speed", prev_speed)
    end
end

local function toggle_script()
    script_enabled = not script_enabled
    local current_speed = mp.get_property_number("speed", 1.0)
    if script_enabled then
        if current_speed < fast_speed then
            prev_speed = current_speed
        end
        mp.observe_property("sub-text", "string", adjust_speed)
        adjust_speed("sub-text", mp.get_property("sub-text", ""))
        mp.osd_message("Non-subtitle speed control: ENABLED")
    else
        mp.unobserve_property(adjust_speed)
        mp.set_property("speed", prev_speed)
        mp.osd_message("Non-subtitle speed control: DISABLED")
    end
end

mp.add_key_binding("ctrl+n", "toggle-speed-control", toggle_script)
