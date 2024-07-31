local function on_window_minimized(_, value)
    if value then
        mp.set_property_native("pause", true)
    else
        mp.add_timeout(0.3, function()
            mp.set_property_native("pause", false)
        end)
    end
end

mp.observe_property("window-minimized", "bool", on_window_minimized)
