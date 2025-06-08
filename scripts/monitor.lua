--- Skyfarm Monitor: Dual-Page UI
--- Created by judea. Last updated: 08/06/2025 11:51:41

-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Setup ===
local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local monitor = peripheral.find("monitor") or error("No monitor found")
monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

-- === State ===
local is_running = false
local debug_trace = false
local active_page = "overview"
local log_lines = {}
local cycle_timer = 0
local drill_state = false
local pusher_lvl = 1
local drawer_last = nil
local drawer_trend = "white"

-- === Display Constants ===
local screen_w, screen_h = monitor.getSize()
local max_logs = screen_h - 2
local color_time = colors.lime
local color_sender = colors.orange

local level_colors = {
    trace = colors.lightGray,
    info  = colors.white,
    warn  = colors.yellow,
    error = colors.red
}

-- === Material Info ===
local materials = {
    Skystone = { name = "Skystone", percent = 0, count = 0, limit = 0 },
    Certus   = { name = "Certus", percent = 0, count = 0, limit = 0 },
    Redstone = { name = "Redstone", percent = 0, count = 0, limit = 0 },
    Quartz   = { name = "Quartz", percent = 0, count = 0, limit = 0 }
}

-- === Utilities ===
local function get_percent_color(p)
    if p < 30 then return colors.white
    elseif p < 60 then return colors.green
    elseif p < 90 then return colors.orange
    else return colors.red end
end

local function secondsToClock(sec)
    local min = math.floor(sec / 60)
    local sec = sec % 60
    return string.format("%02d:%02d", min, sec)
end

local function add_log(entry)
    if entry.level == "trace" and not debug_trace then return end
    table.insert(log_lines, entry)
    if #log_lines > max_logs then table.remove(log_lines, 1) end
end

local function format_log_entry(sender, payload)
    return {
        time = payload.time or os.date("%H:%M:%S"),
        sender = payload.source or config.names[sender] or ("ID " .. tostring(sender)),
        level = payload.level or "info",
        msg = payload.message or tostring(payload)
    }
end

-- === Draw Overview Page ===
local function draw_materials()
    local keys = { "Skystone", "Certus", "Redstone", "Quartz" }
    for row = 1, 2 do
        for col = 1, 2 do
            local index = (row - 1) * 2 + col
            local name = keys[index]
            local mat = materials[name]
            local x = (col - 1) * math.floor(screen_w / 2) + 1
            local y = row * 2

            monitor.setCursorPos(x, y)
            monitor.setTextColor(get_percent_color(mat.percent))
            monitor.write(string.format("%s: %d%%", mat.name, mat.percent))

            monitor.setCursorPos(x, y + 1)
            local c = drawer_trend
            if name == "Skystone" then monitor.setTextColor(colors[c] or colors.white)
            else monitor.setTextColor(colors.white) end
            monitor.write(string.format("%d/%d", mat.count, mat.limit))
        end
    end
end

local function draw_plate_bar()
    local y = 7
    local bar_width = screen_w - 6
    local step = bar_width / 15

    -- Drill indicators
    monitor.setCursorPos(1, y)
    monitor.setTextColor(drill_state and colors.yellow or colors.white)
    monitor.write("■")

    monitor.setCursorPos(screen_w, y)
    monitor.setTextColor(drill_state and colors.white or colors.yellow)
    monitor.write("■")

    -- Plate progress
    for i = 1, 15 do
        local px = 2 + math.floor((i - 1) * step)
        monitor.setCursorPos(px, y)
        monitor.setTextColor(i <= pusher_lvl and colors.yellow or colors.gray)
        monitor.write("■")
    end
end

local function draw_cycle_timer()
    monitor.setCursorPos(math.floor(screen_w / 2) - 3, 8)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Cycle: " .. secondsToClock(cycle_timer))
end

local function draw_overview()
    monitor.clear()
    monitor.setCursorPos(math.floor((screen_w - 15) / 2), 1)
    monitor.setTextColor(colors.white)
    monitor.write("STATUS : ")
    monitor.setTextColor(is_running and colors.lime or colors.orange)
    monitor.write(is_running and "Running" or "Stopped")

    draw_materials()
    draw_plate_bar()
    draw_cycle_timer()

    -- Bottom buttons
    local label = is_running and "[ STOP ]" or "[ START ]"
    monitor.setCursorPos(1, screen_h)
    monitor.setBackgroundColor(is_running and colors.red or colors.green)
    monitor.setTextColor(colors.white)
    monitor.write(label)

    monitor.setCursorPos(screen_w - 6, screen_h)
    monitor.setBackgroundColor(colors.lightBlue)
    monitor.setTextColor(colors.black)
    monitor.write("[LOG]")
end

-- === Draw Logs Page ===
local function draw_logs()
    monitor.clear()
    for i, entry in ipairs(log_lines) do
        monitor.setCursorPos(1, i)
        monitor.setTextColor(color_time)
        monitor.write("[" .. entry.time .. "] ")

        monitor.setTextColor(color_sender)
        monitor.write("[" .. entry.sender .. "] ")

        monitor.setTextColor(level_colors[entry.level] or colors.white)
        monitor.write(entry.msg)
    end

    -- Bottom buttons
    monitor.setCursorPos(1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write("[CLEAR]")

    local label = debug_trace and "[TRACE ✓]" or "[TRACE ×]"
    monitor.setCursorPos(screen_w - #label - 6, screen_h)
    monitor.write(label)

    monitor.setCursorPos(screen_w - 5, screen_h)
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.white)
    monitor.write("[FARM]")
end

local function redraw()
    if active_page == "overview" then draw_overview()
    elseif active_page == "logs" then draw_logs() end
end

-- === Event Handlers ===
local function handle_touch(x, y)
    if y == screen_h then
        if active_page == "overview" then
            if x <= 8 then
                is_running = not is_running
                network.send(config.ids.master, is_running and config.keywords.start or config.keywords.stop, config.protocols.control)
            elseif x >= screen_w - 6 then
                active_page = "logs"
            end
        elseif active_page == "logs" then
            if x <= 8 then
                log_lines = {}
            elseif x >= screen_w - 11 and x <= screen_w - 6 then
                debug_trace = not debug_trace
            elseif x >= screen_w - 5 then
                active_page = "overview"
            end
        end
        redraw()
    end
end

local function listener()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == config.protocols.logs then
            if sender == config.ids.drawer_sky and type(msg) == "table" and msg.data then
                local data = msg.data
                local prev = drawer_last
                drawer_last = data.count
                if prev then
                    if data.count > prev then drawer_trend = "green"
                    elseif data.count < prev then drawer_trend = "red"
                    else drawer_trend = "white"
                    end
                end
                materials["Skystone"].percent = math.floor(data.percent + 0.5)
                materials["Skystone"].count = data.count
                materials["Skystone"].limit = data.limit
            else
                local entry = format_log_entry(sender, msg)
                add_log(entry)
            end
            redraw()

        elseif proto == config.protocols.control then
            is_running = msg == config.keywords.start
            redraw()

        elseif proto == config.protocols.status and msg == config.keywords.ping then
            rednet.send(sender, config.keywords.pong, config.protocols.reply)

        elseif proto == config.protocols.update then
            logging.trace("Updating shared files.")
            shell.run("fetch_modules.lua")
            os.reboot()
        end
    end
end

-- === Launch ===
parallel.waitForAny(
    function()
        while true do
            local _, _, x, y = os.pullEvent("monitor_touch")
            handle_touch(x, y)
        end
    end,
    function()
        while true do
            if is_running then
                cycle_timer = cycle_timer + 1
                redraw()
            end
            sleep(1)
        end
    end,
    listener
)
