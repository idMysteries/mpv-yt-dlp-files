local was_minimized = false

local function on_window_minimized(_, minimized)
    if minimized then
        mp.set_property_native("pause", true)
        was_minimized = true
    elseif was_minimized then
        mp.add_timeout(0.3, function()
            mp.set_property_native("pause", false)
        end)
        was_minimized = false
    end
end

mp.observe_property("window-minimized", "bool", on_window_minimized)
