local utils = require("mp.utils")
local msg = require("mp.msg")

local config = {
    auto_select_first_matching_sub = true,
    max_depth = 2,
}

require("mp.options").read_options(config)

local DEFAULT_SUB_EXTS = {
    "ass", "idx", "lrc", "mks", "pgs", "rt", "sbv", "scc", "smi",
    "srt", "srv3", "ssa", "sub", "sup", "utf", "utf-8", "utf8", "vtt", "ytt"
}

local DEFAULT_VIDEO_EXTS = {
    "3g2", "3gp", "avi", "flv", "ivf", "m2ts", "m4v", "mj2", "mkv",
    "mov", "mp4", "mpeg", "mpg", "mxf", "ogv", "rmvb", "ts", "webm", "wmv", "y4m"
}

local function to_set(array)
    local set = {}
    for _, v in ipairs(array) do
        set[v] = true
    end
    return set
end

local SUB_EXT_SET = to_set(mp.get_property_native("sub-auto-exts") or DEFAULT_SUB_EXTS)
local VID_EXT_SET = to_set(mp.get_property_native("video-exts") or DEFAULT_VIDEO_EXTS)

local function file_ext(path)
    return path:match("%.([^%.]+)$") or ""
end

local function is_sub_file(filename)
    return SUB_EXT_SET[file_ext(filename):lower()]
end

local function is_video_file(filename)
    return VID_EXT_SET[file_ext(filename):lower()]
end

local function filter_array(array, predicate)
    local new = {}
    for _, v in ipairs(array) do
        if predicate(v) then
            table.insert(new, v)
        end
    end
    return new
end

local function index_of(array, key)
    for i, v in ipairs(array) do
        if v == key then return i end
    end
    return nil
end

local function extract_numbers(str)
    local numbers = {}
    for num in str:gmatch("%d+") do
        table.insert(numbers, tonumber(num))
    end
    return numbers
end

local function episode_number(file, sorted_files)
    local idx = index_of(sorted_files, file)
    if not idx then
        msg.warn("Couldn't determine episode number for " .. file)
        return nil
    end

    local numbers = extract_numbers(file)

    local function compare(i)
        local other_numbers = extract_numbers(sorted_files[i])
        for n = 1, #numbers do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return numbers[1]
    end

    for i = idx + 1, #sorted_files do
        local ep = compare(i)
        if ep then return ep end
    end
    for i = idx - 1, 1, -1 do
        local ep = compare(i)
        if ep then return ep end
    end

    msg.warn("Couldn't determine episode number for " .. file)
    return nil
end

local function collect_subs(dir, prefix, depth)
    prefix = prefix or ""
    depth = depth or 0
    local results = {}

    local files = utils.readdir(dir, "files")
    if files then
        for _, f in ipairs(files) do
            if depth > 0 and is_video_file(f) then
                return {}
            elseif is_sub_file(f) then
                table.insert(results, {
                    path = utils.join_path(dir, f),
                    name = prefix .. f,
                })
            end
        end
    end

    if depth >= config.max_depth then
        return results
    end

    local subdirs = utils.readdir(dir, "dirs") or {}
    table.sort(subdirs)
    
    for _, subdir in ipairs(subdirs) do
        local next_dir = utils.join_path(dir, subdir)
        local sub_results = collect_subs(next_dir, prefix .. subdir .. "/", depth + 1)
        for _, entry in ipairs(sub_results) do
            table.insert(results, entry)
        end
    end

    return results
end

local function sorted_copy(array)
    local copy = {unpack(array)}
    table.sort(copy)
    return copy
end

local function load_subs()
    local path = mp.get_property("path")
    
    if not path or path:find("://") then return end

    local dir, file = utils.split_path(path)

    local all_files = utils.readdir(dir, "files")
    if not all_files then return end

    local sub_entries = collect_subs(dir)
    if not next(sub_entries) then return end

    local videos = filter_array(all_files, is_video_file)
    local sorted_videos = sorted_copy(videos)
    local episode = episode_number(file, sorted_videos)
    if not episode and #videos > 1 then return end

    local sub_names = {}
    for i, entry in ipairs(sub_entries) do
        sub_names[i] = entry.name
    end
    local sorted_sub_names = sorted_copy(sub_names)

    if config.auto_select_first_matching_sub then
        table.sort(sub_entries, function(a, b) return a.name > b.name end)
    else
        table.sort(sub_entries, function(a, b) return a.name < b.name end)
    end

    for _, entry in ipairs(sub_entries) do
        if not episode or
           episode_number(entry.name, sorted_sub_names) == episode then
            mp.commandv("sub-add", entry.path)
            msg.info("Added subtitle: " .. entry.name)
        end
    end
end

mp.add_hook('on_preloaded', 50, load_subs)
