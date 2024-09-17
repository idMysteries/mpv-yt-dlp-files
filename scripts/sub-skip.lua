local cfg = {
	enabled = false,
	min_skip_interval = 2,
	speed_skip_speed = 1.75,
	lead_in = 0.3,
	lead_out = 0.2,
	blacklist = {'♬', '～♬', '♬～', '♫', '～♫', '♫～', '☎', '♪', '♪～', '～♪'}
}
require("mp.options").read_options(cfg)

if type(cfg.blacklist) == 'string' then
	cfg.blacklist = load("return " .. cfg.blacklist)()
end
local active = cfg.enabled
local skipping = false
local sped_up = false
local blacklist_skip = false
local last_sub_end, next_sub_start

local initialised_blacklist = {}

for i,v in ipairs(cfg.blacklist) do
	initialised_blacklist[v] = 1
end

function get_delay_to_next_sub()
	local initial_sub_visibility = mp.get_property_bool("sub-visibility")
	mp.set_property_bool("sub-visibility", false)

	local initial_sub_delay = mp.get_property_number("sub-delay") or 0
	local current_sub

	repeat
		mp.commandv("sub-step", "1")
		current_sub = mp.get_property('sub-text') or ""
	until(not initialised_blacklist[current_sub])

	local next_sub_delay = mp.get_property_number("sub-delay") or 0
	mp.set_property_number("sub-delay", initial_sub_delay)

	mp.set_property_bool("sub-visibility", initial_sub_visibility)

	if initial_sub_delay > next_sub_delay then
        return initial_sub_delay - next_sub_delay
    else
        return nil
    end
end

local initial_speed = mp.get_property_number("speed")
local initial_video_sync = mp.get_property("video-sync")
function handle_tick(_, time_pos)
	if time_pos == nil then return end

	if not sped_up and time_pos > last_sub_end + cfg.lead_in then
		initial_speed = mp.get_property_number("speed")
		initial_video_sync = mp.get_property("video-sync")
		mp.set_property("video-sync", "desync")
		mp.set_property_number("speed", cfg.speed_skip_speed)
		sped_up = true
	elseif sped_up and next_sub_start == nil then
		local next_delay = get_delay_to_next_sub()
		if next_delay ~= nil then
			next_sub_start = time_pos + next_delay
		end
	elseif sped_up and time_pos > next_sub_start - cfg.lead_out then
		end_skip()
	end
end

function start_skip()
	local time_pos = mp.get_property_number("time-pos")
	local next_delay = get_delay_to_next_sub()

	if not time_pos then
		last_sub_end = -cfg.lead_in
	else
		last_sub_end = time_pos
	end
	if next_delay ~= nil then
		if next_delay < cfg.min_skip_interval then return
		else next_sub_start = time_pos + next_delay end
	end
	skipping = true
	mp.observe_property("time-pos", "number", handle_tick)
end

function end_skip()
	mp.unobserve_property(handle_tick)
	skipping = false
	sped_up = false
	blacklist_skip = false
	mp.set_property_number("speed", initial_speed)
	mp.set_property("video-sync", initial_video_sync)
	last_sub_end, next_sub_start = nil
end

function handle_sub_change(_, sub_end)
	if mp.get_property_number('sid', -1) == -1 then
		return
	end
	sub_text = mp.get_property('sub-text')
	if not blacklist_skip and initialised_blacklist[sub_text] then
		blacklist_skip = true
		start_skip()
	elseif not sub_end and not skipping then
		start_skip()
	elseif not blacklist_skip and skipping and sub_end and sub_text ~= '' then
		end_skip()
	end
end

function activate()
	mp.observe_property("sub-end", "number", handle_sub_change)
	active = true
end

function deactivate()
	end_skip()
	mp.unobserve_property(handle_sub_change)
	active = false
end

function toggle_script()
	if active then
		deactivate()
		mp.osd_message("Non-subtitle skip disabled")
	else
		activate()
		mp.osd_message("Non-subtitle skip enabled")
	end
end

if active then activate() end

mp.add_key_binding("Ctrl+n", "toggle", toggle_script)
