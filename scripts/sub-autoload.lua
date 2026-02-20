local utils = require("mp.utils")
local msg = require("mp.msg")

local sep = package.config:sub(1, 1)
local MAX_DEPTH = 2

local function build_ext_set(prop)
    local val = mp.get_property_native(prop, {})
    local set = {}
    if type(val) == "table" then
        for _, e in ipairs(val) do set[e:lower()] = true end
    end
    return set
end

local SUB_EXTS = build_ext_set("sub-auto-exts")
local VID_EXTS = build_ext_set("video-exts")

local function file_ext(path)
    return (path:match("%.([^%.]+)$") or ""):lower()
end

local function file_name(path)
    return path:match("([^/\\]+)$") or path
end

local function basename(path)
    local name = file_name(path)
    return name:match("(.+)%.[^%.]+$") or name
end

local function normalize(name)
    name = name:lower()
    name = name:gsub("%[.-%]", " ")
    name = name:gsub("%(.-%)","  ")
    name = name:gsub("[%.%-%_%+%{%}]", " ")
    name = name:gsub("%s+", " ")
    return name:match("^%s*(.-)%s*$")
end

local function extract_numbers(str)
    local numbers = {}
    str:gsub("%d+", function(num) table.insert(numbers, tonumber(num)) end)
    return numbers
end

local function episode_number(file, files)
    if #files <= 1 then
        local nums = extract_numbers(file)
        return nums[#nums]
    end

    local sorted = {}
    for _, f in ipairs(files) do table.insert(sorted, f) end
    table.sort(sorted)

    local current_index
    for i, f in ipairs(sorted) do
        if f == file then current_index = i; break end
    end
    if not current_index then return nil end

    local numbers = extract_numbers(file)
    if #numbers == 0 then return nil end

    local function find_episode_vs(other)
        local other_numbers = extract_numbers(other)
        for n = 1, math.min(#numbers, #other_numbers) do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return nil
    end

    for i = current_index + 1, #sorted do
        local ep = find_episode_vs(sorted[i])
        if ep then return ep end
    end
    for i = current_index - 1, 1, -1 do
        local ep = find_episode_vs(sorted[i])
        if ep then return ep end
    end

    return numbers[#numbers]
end

local function scan_subs(dir, depth)
    local subs = {}

    local files = utils.readdir(dir, "files")
    if not files then return subs end

    for _, f in ipairs(files) do
        local e = file_ext(f)
        if VID_EXTS[e] then
            if depth > 0 then return {} end
        elseif SUB_EXTS[e] then
            table.insert(subs, utils.join_path(dir, f))
        end
    end

    if depth < MAX_DEPTH then
        local dirs = utils.readdir(dir, "dirs")
        if dirs then
            for _, d in ipairs(dirs) do
                if not d:match("^%.") then
                    local child = scan_subs(utils.join_path(dir, d), depth + 1)
                    for _, s in ipairs(child) do
                        table.insert(subs, s)
                    end
                end
            end
        end
    end

    return subs
end

local function word_dice(a, b)
    local wa, wb = {}, {}
    for w in a:gmatch("%S+") do wa[w] = true end
    for w in b:gmatch("%S+") do wb[w] = true end
    local ca, cb, common = 0, 0, 0
    for w in pairs(wa) do ca = ca + 1; if wb[w] then common = common + 1 end end
    for _ in pairs(wb) do cb = cb + 1 end
    if ca + cb == 0 then return 0 end
    return (2 * common) / (ca + cb)
end

local function find_and_load()
    local path = mp.get_property("path")
    if not path then return end
    if path:match("^%a+://") and not path:match("^file://") then return end

    local dir = path:match("(.*" .. sep .. ")") or "."
    local fname = file_name(path)

    local all_files = utils.readdir(dir, "files") or {}
    local videos = {}
    for _, f in ipairs(all_files) do
        if VID_EXTS[file_ext(f)] then
            table.insert(videos, f)
        end
    end

    local vid_episode = episode_number(fname, videos)
    local vid_norm = normalize(basename(fname))

    local subs = scan_subs(dir, 0)
    if #subs == 0 then return end

    local subs_by_dir = {}
    for _, sp in ipairs(subs) do
        local sd = sp:match("(.*" .. sep .. ")") or dir
        if not subs_by_dir[sd] then subs_by_dir[sd] = {} end
        table.insert(subs_by_dir[sd], file_name(sp))
    end

    local candidates = {}

    for _, sp in ipairs(subs) do
        local sf = file_name(sp)
        local sb = basename(sf)
        local sn = normalize(sb)
        local sd = sp:match("(.*" .. sep .. ")") or dir
        local sub_siblings = subs_by_dir[sd] or {}

        local dominated = false
        local score = 0

        if vid_norm == sn then
            score = 1000
        else
            local sub_episode = episode_number(sf, sub_siblings)

            if vid_episode and sub_episode then
                if vid_episode == sub_episode then
                    score = score + 500
                else
                    dominated = true
                end
            end

            if not dominated then
                local dice = word_dice(vid_norm, sn)
                score = score + dice * 300

                if vid_norm:find(sn, 1, true) or sn:find(vid_norm, 1, true) then
                    score = score + 80
                end
            end
        end

        if not dominated and score < 100 then
            if sd == dir and #videos == 1 and #sub_siblings == 1 then
                score = math.max(score, 200)
            end
        end

        if not dominated and score >= 100 then
            table.insert(candidates, { path = sp, score = score })
        end
    end

    table.sort(candidates, function(a, b) return a.score > b.score end)

    local existing = {}
    local tracks = mp.get_property_native("track-list", {})
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t["external-filename"] then
            existing[t["external-filename"]] = true
        end
    end

    for _, c in ipairs(candidates) do
        if not existing[c.path] then
            msg.info("Loaded: " .. c.path .. " (score: " .. c.score .. ")")
            mp.commandv("sub-add", c.path)
        end
    end

    if #candidates == 0 then
        msg.verbose("No matching subtitles found")
    end
end

mp.add_hook("on_preloaded", 50, find_and_load)
