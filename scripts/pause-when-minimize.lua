mp.observe_property("window-minimized", "bool", function(_, value)
    local pause = mp.get_property_native("pause")
    if value == true then
        mp.set_property_native("pause", true)
    elseif value == false then
        mp.add_timeout(0.3, function() mp.set_property_native("pause", false) end)
    end
end)
