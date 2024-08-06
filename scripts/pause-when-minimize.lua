local was_minimized = false

local function on_window_minimized(_, value)
    if value then
        was_minimized = true
        mp.set_property_native("pause", true)
    else
        if was_minimized then
            mp.add_timeout(0.3, function()
                mp.set_property_native("pause", false)
            end)
        end
        was_minimized = false
    end
end

mp.observe_property("window-minimized", "bool", on_window_minimized)
