--[[
    fuzzydir / by sibwaf / https://github.com/sibwaf/mpv-scripts

    Allows using "**" wildcards in sub-file-paths and audio-file-paths
    so you don't have to specify all the possible directory names.

    Basically, allows you to do this and never have the need to edit any paths ever again:
    audio-file-paths = **
    sub-file-paths = **

    MIT license - do whatever you want, but I'm not responsible for any possible problems.
    Please keep the URL to the original repository. Thanks!
]]

--[[
    Configuration:

    # enabled

    Determines whether the script is enabled or not

    # max_search_depth

    Determines the max depth of recursive search, should be >= 1

    Examples for "sub-file-paths = **":
    "max_search_depth = 1" => mpv will be able to find [xyz.ass, subs/xyz.ass]
    "max_search_depth = 2" => mpv will be able to find [xyz.ass, subs/xyz.ass, subs/moresubs/xyz.ass]

    Please be careful when setting this value too high as it can result in awful performance or even stack overflow


    # discovery_threshold

    fuzzydir will skip paths which contain more than discovery_threshold directories in them

    This is done to keep at least some garbage from getting into *-file-paths properties in case of big collections:
    - dir1 <- will be ignored on opening video.mp4 as it's probably unrelated to the file
    - ...
    - dir999 <- will be ignored
    - video.mp4

    Use 0 to disable this behavior completely


    # use_powershell

    fuzzydir will use PowerShell to traverse directories when it's available

    Can be faster in some cases, but can also be significantly slower
]]

local msg = require 'mp.msg'
local utils = require 'mp.utils'
local options = require 'mp.options'

local o = {
    enabled = true,
    max_search_depth = 3,
    discovery_threshold = 10,
    use_powershell = false,
}
options.read_options(o)

----------
local default_audio_paths = mp.get_property_native("options/audio-file-paths")
local default_sub_paths = mp.get_property_native("options/sub-file-paths")

local function starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function ends_with(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
end

local function contains(t, e)
    for _, element in ipairs(t) do
        if element == e then
            return true
        end
    end
    return false
end

local function normalize(path)
    if path == "." then
        return ""
    end

    if starts_with(path, "./") or starts_with(path, ".\\") then
        path = path:sub(3)
    end
    if ends_with(path, "/") or ends_with(path, "\\") then
        path = path:sub(1, -2)
    end

    return path
end

local function call_command(command)
    local command_string = table.concat(command, " ")

    msg.trace("Calling external command:", command_string)

    local process = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = command,
    })

    if process.status ~= 0 then
        msg.verbose("External command failed with status " .. process.status .. ": " .. command_string)
        if process.stderr ~= "" then
            msg.debug(process.stderr)
        end

        return nil
    end

    local result = {}
    for line in process.stdout:gmatch("[^\r\n]+") do
        table.insert(result, line)
    end
    return result
end

-- Platform-dependent optimization

local powershell_version = nil
if o.use_powershell then
    local version_output = call_command({
        "powershell",
        "-NoProfile",
        "-Command",
        "$Host.Version.Major",
    })
    if version_output and version_output[1] then
        powershell_version = tonumber(version_output[1]) or -1
    else
        powershell_version = -1
    end
else
    powershell_version = -1
end
msg.debug("PowerShell version", powershell_version)

local function fast_readdir(path)
    if powershell_version >= 3 then
        msg.trace("Scanning", path, "with PowerShell")
        local result = call_command({
            "powershell",
            "-NoProfile",
            "-Command",
            string.format([[
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $ErrorActionPreference = 'SilentlyContinue'
            $dirs = Get-ChildItem -LiteralPath %s -Directory
            foreach($dir in $dirs) {
                Write-Output $dir.Name
            } ]], utils.format_json(path))
        })
        msg.trace("Finished scanning", path, "with PowerShell")
        return result
    end

    msg.trace("Scanning", path, "with default readdir")
    local result = utils.readdir(path, "dirs")
    msg.trace("Finished scanning", path, "with default readdir")
    return result
end

-- Platform-dependent optimization end

local function traverse(search_path, current_path)
    local stack = {}
    local result = {}
    table.insert(stack, { path = current_path, level = 1 })

    while #stack > 0 do
        local node = table.remove(stack)
        local full_path = utils.join_path(search_path, node.path)

        if node.level > o.max_search_depth then
            msg.trace("Traversed too deep, skipping scan for", full_path)
        else
            local dirs = fast_readdir(full_path) or {}
            if o.discovery_threshold > 0 and #dirs > o.discovery_threshold then
                msg.debug("Too many directories in " .. full_path .. ", skipping")
            else
                for _, dir in ipairs(dirs) do
                    local new_path = utils.join_path(node.path, dir)
                    table.insert(result, new_path)
                    table.insert(stack, { path = new_path, level = node.level + 1 })
                end
            end
        end
    end

    return result
end

local function explode(raw_paths, search_path)
    local result = {}
    for _, raw_path in ipairs(raw_paths) do
        local parent, leftover = utils.split_path(raw_path)
        if leftover == "**" then
            msg.trace("Expanding wildcard for", raw_path)
            table.insert(result, parent)
            local expanded_paths = traverse(search_path, parent)
            for _, p in ipairs(expanded_paths) do
                local normalized_path = normalize(p)
                if not contains(result, normalized_path) and normalized_path ~= "" then
                    table.insert(result, normalized_path)
                end
            end
        else
            msg.trace("Path", raw_path, "doesn't have a wildcard, keeping as-is")
            table.insert(result, normalize(raw_path))
        end
    end

    return result
end

local function explode_all()
    if not o.enabled then return end
    msg.debug("max_search_depth = ".. o.max_search_depth .. ", discovery_threshold = " .. o.discovery_threshold)

    local video_path = mp.get_property("path")
    local search_path = utils.split_path(video_path)
    msg.debug("search_path = " .. search_path)

    msg.debug("Processing audio-file-paths")
    local audio_paths = explode(default_audio_paths, search_path)
    for _, path in ipairs(audio_paths) do
        msg.debug("Adding to audio-file-paths:", path)
    end
    mp.set_property_native("options/audio-file-paths", audio_paths)

    msg.debug("Processing sub-file-paths")
    local sub_paths = audio_paths
    if table.concat(default_audio_paths) ~= table.concat(default_sub_paths) then
        sub_paths = explode(default_sub_paths, search_path)
    end

    for _, path in ipairs(sub_paths) do
        msg.debug("Adding to sub-file-paths:", path)
    end
    mp.set_property_native("options/sub-file-paths", sub_paths)

    msg.debug("Done expanding paths")
end

mp.add_hook("on_load", 50, explode_all)
