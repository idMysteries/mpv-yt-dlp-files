local mp = require 'mp'
local options = require 'mp.options'

local o = {
    enabled = false,
    skip_once = true,
    categories = "",
    skip = "sponsor;"
}

options.read_options(o)

local default_categories = {
    prologue = { "^[Pp]rologue", "^[Ii]ntro" },
    opening = { "^OP", "OP$", "^[Oo]pening", "[Oo]pening$", "^[Оо]пен.нг", "[Оо]пен.нг$" },
    ending = { "^ED", "ED$", "^[Ee]nding", "[Ee]nding$", "^[Ээ]нд.нг", "[Ээ]нд.нг$" },
    credits = { "^[Cc]redits", "[Cc]redits$" },
    preview = { "[Pp]review$" },
    sponsor = { "%[SponsorBlock%]:.*Sponsor" }
}

local categories = {}
local skip_patterns = {}

local function update_categories()
    categories = {}
    for k, v in pairs(default_categories) do
        categories[k] = v
    end

    for category, patterns in o.categories:gmatch("([^+>]+)[+>]([^;]+)") do
        local lower_name = category:lower():match("^%s*(.-)%s*$")
        categories[lower_name] = {}
        for pattern in patterns:gmatch("([^/]+)") do
            table.insert(categories[lower_name], pattern)
        end
    end
end

local function update_skip_patterns()
    skip_patterns = {}
    for category in o.skip:gmatch("([^;]+)") do
        local patterns = categories[category:lower()]
        if patterns then
            for _, pattern in ipairs(patterns) do
                table.insert(skip_patterns, pattern)
            end
        end
    end
end

update_categories()
update_skip_patterns()

local function matches(title)
    for _, pattern in ipairs(skip_patterns) do
        if title:match(pattern) then
            return true
        end
    end
    return false
end

local skipped = {}
local chapters = nil

local function chapterskip(_, current_chapter_index)
    if not o.enabled or not current_chapter_index or current_chapter_index < 0 then return end

    chapters = chapters or mp.get_property_native("chapter-list") or {}
    local num_chapters = #chapters
    local i = current_chapter_index + 1
    local skip_occurred = false

    while i <= num_chapters do
        local chapter = chapters[i]
        if (not o.skip_once or not skipped[i]) and matches(chapter.title) then
            skipped[i] = true
            skip_occurred = true
            i = i + 1
        else
            break
        end
    end

    if skip_occurred then
        local target_time
        if i <= num_chapters then
            target_time = chapters[i].time
        else
            target_time = mp.get_property_number("duration")
        end
        if target_time then
            mp.set_property_number("time-pos", target_time)
        end
    end
end

mp.observe_property("chapter", "number", chapterskip)

mp.register_event("file-loaded", function()
    skipped = {}
    chapters = nil
end)

mp.add_key_binding("y", "chapterskip_toggle", function()
    o.enabled = not o.enabled
    mp.osd_message(o.enabled and "Chapter skip enabled" or "Chapter skip disabled")
end)
