local utils = require("mp.utils")
local msg = require("mp.msg")

local sub_exts = mp.get_property_native("sub-auto-exts")

local config = {
    auto_select_first_matching_sub = true,
    sub_search_depth = 0,
}
require("mp.options").read_options(config)

local function base_dir(path)
    return path:match("^(.*[/\\])")
end

local function file_name(path)
    return path:match("([^/\\]+)$")
end

local function file_ext(name)
    return name:match(".*%.(.*)") or ""
end

local function extract_numbers(str)
    local numbers = {}
    str:gsub("%d+", function(num) numbers[#numbers + 1] = tonumber(num) end)
    return numbers
end

local function index_of(array, key)
    for i, v in ipairs(array) do
        if v == key then return i end
    end
    return nil
end

local function array_has(array, key)
    return index_of(array, key) ~= nil
end

local function filter_array(array, predicate)
    local new = {}
    for _, v in ipairs(array) do
        if predicate(v) then new[#new + 1] = v end
    end
    return new
end

local function is_sub_already_loaded(sub_name)
    local tracks = mp.get_property_native("track-list", {})
    for _, track in ipairs(tracks) do
        if track.type == "sub" and track["external-filename"] then
            if file_name(track["external-filename"]) == sub_name then
                return true
            end
        end
    end
    return false
end

local function collect_files_recursive(dir, max_depth, current_depth)
    current_depth = current_depth or 0
    local result = {}
    local seen = {}

    local function scan(d, depth)
        local files = utils.readdir(d, "files")
        if files then
            for _, f in ipairs(files) do
                if not seen[f] then
                    seen[f] = true
                    result[#result + 1] = { name = f, path = d .. f }
                end
            end
        end

        if depth < max_depth then
            local dirs = utils.readdir(d, "dirs")
            if dirs then
                table.sort(dirs)
                for _, sub in ipairs(dirs) do
                    scan(d .. sub .. "/", depth + 1)
                end
            end
        end
    end

    scan(dir, current_depth)
    return result
end

local function episode_number(file, sorted_files)
    local idx = index_of(sorted_files, file)
    if not idx then
        msg.warn("File not found in list: " .. file)
        return nil
    end

    local numbers = extract_numbers(file)
    if #numbers == 0 then
        msg.warn("No numbers found in: " .. file)
        return nil
    end

    local function find_episode_vs(other_idx)
        local other_numbers = extract_numbers(sorted_files[other_idx])
        for n = 1, math.min(#numbers, #other_numbers) do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return nil
    end

    for i = idx + 1, #sorted_files do
        local ep = find_episode_vs(i)
        if ep then return ep end
    end
    for i = idx - 1, 1, -1 do
        local ep = find_episode_vs(i)
        if ep then return ep end
    end

    return numbers[1]
end

local function sub_matches_episode(sub_file, episode)
    local numbers = extract_numbers(sub_file)
    return array_has(numbers, episode)
end

local function load_subs()
    local path = mp.get_property("path")
    if not path then return end

    local dir  = base_dir(path)
    local file = file_name(path)
    if not dir or not file then return end

    local ext = file_ext(file):lower()

    local all_files_current = utils.readdir(dir, "files")
    if not all_files_current then return end

    local videos = filter_array(all_files_current, function(f)
        return file_ext(f):lower() == ext
    end)
    table.sort(videos)

    local episode = episode_number(file, videos)
    if not episode then return end

    local all_entries = collect_files_recursive(dir, config.sub_search_depth)

    local sub_entries = filter_array(all_entries, function(entry)
        return array_has(sub_exts, file_ext(entry.name):lower())
    end)
    if #sub_entries == 0 then return end

    local groups = {}
    for _, entry in ipairs(sub_entries) do
        local key = entry.name:gsub("%d+", "#")
        if not groups[key] then groups[key] = {} end
        groups[key][#groups[key] + 1] = entry
    end

    local matched_subs = {}

    for _, group in pairs(groups) do
        if #group > 1 then
            table.sort(group, function(a, b) return a.name < b.name end)
            local names = {}
            for i, entry in ipairs(group) do names[i] = entry.name end

            for i, entry in ipairs(group) do
                if episode_number(entry.name, names) == episode then
                    matched_subs[#matched_subs + 1] = entry
                end
            end
        else
            if sub_matches_episode(group[1].name, episode) then
                matched_subs[#matched_subs + 1] = group[1]
            end
        end
    end

    if config.auto_select_first_matching_sub then
        table.sort(matched_subs, function(a, b) return a.name > b.name end)
    else
        table.sort(matched_subs, function(a, b) return a.name < b.name end)
    end

    for _, entry in ipairs(matched_subs) do
        if not is_sub_already_loaded(entry.name) then
            mp.commandv("sub-add", entry.path)
            msg.info("Added subtitle: " .. entry.path)
        end
    end
end

mp.add_hook("on_preloaded", 50, load_subs)
