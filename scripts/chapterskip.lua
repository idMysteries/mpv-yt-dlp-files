local mp = require 'mp'
local msg = require 'mp.msg'
local options = require 'mp.options'

local o = {
    enabled = false,
    skip_once = true,
    categories = "",
    skip = "opening;ending;"
}

options.read_options(o)

local default_categories = {
    prologue = { "^[Pp]rologue", "^[Ii]ntro" },
    opening = { "^OP", "OP$", "^[Oo]pening", "^[Oo]pening$" },
    ending = { "^ED", "ED$", "^[Ee]nding", "^[Ee]nding$" },
    credits = { "^[Cc]redits", "[Cc]redits$" },
    preview = { "[Pp]review$" }
}

local categories = {}

local function update_categories()
    categories = {}
    for k, v in pairs(default_categories) do
        categories[k] = v
    end

    for category in string.gmatch(o.categories, "([^;]+)") do
        local name, patterns = category:match(" *([^+>]+) *[+>](.*)")
        if name and patterns then
            local lower_name = name:lower()
            categories[lower_name] = {}
            for pattern in patterns:gmatch("([^/]+)") do
                table.insert(categories[lower_name], pattern)
            end
        else
            msg.warn("Improper category definition: " .. category)
        end
    end
end

update_categories()

local function matches(title)
    for category in o.skip:gmatch("([^;]+)") do
        local patterns = categories[category:lower()]
        if patterns then
            for _, pattern in ipairs(patterns) do
                if title:match(pattern) then
                    return true
                end
            end
        end
    end
    return false
end

local skipped = {}
local chapters = nil

local function chapterskip(_, current_chapter_index)
    if not o.enabled or not current_chapter_index then return end
    
    if not chapters then
        chapters = mp.get_property_native("chapter-list") or {}
    end

    local skip_index = nil

    for i = current_chapter_index + 1, #chapters do
        local chapter = chapters[i]

        if (not o.skip_once or not skipped[i]) and matches(chapter.title) then
            if i == current_chapter_index + 1 or (skip_index and i == skip_index + 1) then
                if skip_index then
                    skipped[skip_index] = true
                end
                skip_index = i
            end
        elseif skip_index then
            mp.set_property("time-pos", chapter.time)
            skipped[skip_index] = true
            return
        end
    end

    if skip_index then
        mp.set_property("time-pos", mp.get_property("duration"))
    end
end

mp.observe_property("chapter", "number", chapterskip)
mp.register_event("file-loaded", function()
    skipped = {}
    chapters = nil
end)
