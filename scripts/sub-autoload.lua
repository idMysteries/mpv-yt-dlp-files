local utils = require("mp.utils")
local msg = require("mp.msg")

local MAX_DEPTH = 2
local MIN_SCORE = 100
local SOLO_RULE = true

local function build_ext_set(prop)
    local val = mp.get_property_native(prop, {})
    local set = {}
    if type(val) == "table" then
        for _, e in ipairs(val) do
            set[e:lower()] = true
        end
    elseif type(val) == "string" then
        for e in val:gmatch("[^,]+") do
            set[e:lower():match("^%s*(.-)%s*$")] = true
        end
    end
    return set
end

local SUB_EXTS = build_ext_set("options/sub-auto-exts")
local VID_EXTS = build_ext_set("options/video-exts")

local function ext(f)
    return (f:match("%.([^%.]+)$") or ""):lower()
end

local function basename(f)
    local name = f:match("([^/\\]+)$") or f
    return name:match("(.+)%.[^%.]+$") or name
end

local function filename_of(path)
    return path:match("([^/\\]+)$") or path
end

local function normalize(name)
    name = name:lower()
    name = name:gsub("%[.-%]", " ")
    name = name:gsub("%(.-%)","  ")
    name = name:gsub("[%.%-%_%+%{%}]", " ")
    name = name:gsub("%s+", " ")
    return name:match("^%s*(.-)%s*$")
end

local function parse_episode(name)
    local n = name:lower()
    local s, e

    s, e = n:match("s(%d+)e(%d+)")
    if s then return tonumber(s), tonumber(e) end

    s, e = n:match("(%d+)x(%d+)")
    if s then return tonumber(s), tonumber(e) end

    s = n:match("season[%s%.%-_]*(%d+)")
    e = n:match("episode[%s%.%-_]*(%d+)")
    if s and e then return tonumber(s), tonumber(e) end

    e = n:match("%s%-+%s+(%d%d%d?)%s")
    if e then return nil, tonumber(e) end

    e = n:match("[^%d]e(%d+)")
    if e then return nil, tonumber(e) end

    return nil, nil
end

local function extract_title(name)
    local n = normalize(name)
    local t = n:match("^(.-)%s+s%d+e%d+")
           or n:match("^(.-)%s+%d+x%d+")
           or n:match("^(.-)%s+season%s")
           or n:match("^(.-)%s+%-%s+%d%d")
           or n:match("^(.-)%s+e%d+%s")

    if not t or t == "" then
        t = n:match("^(.-)%s+[12]%d%d%d%s")
    end
    if not t or t == "" then
        t = n:match("^(.-)%s+%d+p[%s$]")
         or n:match("^(.-)%s+bluray")
         or n:match("^(.-)%s+bdrip")
         or n:match("^(.-)%s+webrip")
         or n:match("^(.-)%s+web%s")
         or n:match("^(.-)%s+hdtv")
         or n:match("^(.-)%s+dvdrip")
         or n:match("^(.-)%s+hdr")
    end
    if not t or t == "" then t = n end
    t = t:gsub("%s+[12]%d%d%d%s*$", "")
    return t:match("^%s*(.-)%s*$")
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

local function score_match(vid, sub)
    local vn = normalize(vid)
    local sn = normalize(sub)
    if vn == sn then return 1000 end

    local score = 0

    local vs, ve = parse_episode(vid)
    local ss, se = parse_episode(sub)

    if ve and se then
        if ve == se and (vs == ss or vs == nil or ss == nil) then
            score = score + 500
        else
            return 0
        end
    end

    local vt = extract_title(vid)
    local st = extract_title(sub)

    if vt ~= "" and st ~= "" then
        score = score + word_dice(vt, st) * 300
        if vt == st then score = score + 100 end
    end

    score = score + word_dice(vn, sn) * 50

    if vn:find(sn, 1, true) or sn:find(vn, 1, true) then
        score = score + 80
    end

    return score
end

local function scan_dir(dir, depth)
    local subs = {}
    local vid_count, sub_count = 0, 0

    local files = utils.readdir(dir, "files")
    if not files then return subs, vid_count, sub_count end

    for _, f in ipairs(files) do
        if SUB_EXTS[ext(f)] then
            table.insert(subs, utils.join_path(dir, f))
            sub_count = sub_count + 1
        elseif VID_EXTS[ext(f)] then
            vid_count = vid_count + 1
        end
    end

    if depth < MAX_DEPTH then
        local dirs = utils.readdir(dir, "dirs")
        if dirs then
            for _, d in ipairs(dirs) do
                if not d:match("^%.") then
                    local child_subs = scan_dir(utils.join_path(dir, d), depth + 1)
                    for _, s in ipairs(child_subs) do
                        table.insert(subs, s)
                    end
                end
            end
        end
    end

    return subs, vid_count, sub_count
end

local function find_and_load()
    local filepath = mp.get_property("path")
    if not filepath then return end
    if filepath:match("^%a+://") and not filepath:match("^file://") then return end

    local dir, fname = utils.split_path(filepath)
    if not dir or dir == "" then dir = "." end
    local vid_base = basename(fname)

    local subs, vid_count, sub_count = scan_dir(dir, 0)
    if #subs == 0 then return end

    local candidates = {}
    for _, sp in ipairs(subs) do
        local sf = filename_of(sp)
        local sb = basename(sf)
        local sc = score_match(vid_base, sb)

        if SOLO_RULE and sc < MIN_SCORE then
            local sd = utils.split_path(sp)
            if sd == dir and vid_count == 1 and sub_count == 1 then
                sc = math.max(sc, 200)
            end
        end

        if sc >= MIN_SCORE then
            table.insert(candidates, { path = sp, score = sc })
        end
    end

    table.sort(candidates, function(a, b) return a.score > b.score end)

    for _, c in ipairs(candidates) do
        mp.commandv("sub-add", c.path)
    end
end

mp.add_hook("on_preloaded", 50, find_and_load)
