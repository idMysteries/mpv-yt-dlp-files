local mp = require 'mp'
local msg = require 'mp.msg'
local options = {
    enabled = false,
    skip_once = true,
    categories = "",
    skip = "opening;ending;"
}

mp.options = require "mp.options"
mp.options.read_options(options)

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

    for category in string.gmatch(options.categories, "([^;]+)") do
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

local function matches(i, title)
    for category in options.skip:gmatch("([^;]+)") do
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

local function chapterskip(_, current)
    if not options.enabled then return end

    local chapters = mp.get_property_native("chapter-list") or {}
    local skip = nil

    for i, chapter in ipairs(chapters) do
        if (not options.skip_once or not skipped[i]) and matches(i, chapter.title) then
            if i == current + 1 or (skip and i == skip + 1) then
                if skip then
                    skipped[skip] = true
                end
                skip = i
            end
        elseif skip then
            mp.set_property("time-pos", chapter.time)
            skipped[skip] = true
            return
        end
    end

    if skip then
        mp.set_property("time-pos", mp.get_property("duration"))
    end
end

mp.observe_property("chapter", "number", chapterskip)
mp.register_event("file-loaded", function() skipped = {} end)
