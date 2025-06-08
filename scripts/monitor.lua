--- Skyfarm Monitor with Graphical UI
--- Created by judea. Updated: 8/06/2025

-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Setup ===
local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local monitor = peripheral.find("monitor") or error("No monitor found")
monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.clear()

-- === State ===
local is_running = false
local debug_trace = false
local log_lines = {}
local screen_w, screen_h = monitor.getSize()
local log_area_height = screen_h - 7

-- === Color Settings ===
local color_time   = colors.lime
local color_sender = colors.orange
local level_colors = {
    trace = colors.lightGray,
    info  = colors.white,
    warn  = colors.yellow,
    error = colors.red
}

-- === Material Info ===
local materials = {
    Skystone = { percent = 0, count = 0, limit = 0 },
    Certus   = { percent = 0, count = 0, limit = 0 },
    Redstone = { percent = 0, count = 0, limit = 0 },
    Quartz   = { percent = 0, count = 0, limit = 0 }
}

local function get_percent_color(p)
    if p < 30 then return colors.white
    elseif p < 60 then return colors.green
    elseif p < 90 then return colors.orange
    else return colors.red end
end

-- === Drawing UI ===
local function draw_top_section()
    local status_text = is_running and "Running" or "Stopped"
    local status_color = is_running and colors.lime or colors.orange
    local status_x = math.floor((screen_w - 15) / 2)
    monitor.setCursorPos(status_x, 1)
    monitor.setTextColor(colors.white)
    monitor.write("STATUS : ")
    monitor.setTextColor(status_color)
    monitor.write(status_text)

    local keys = { "Skystone", "Certus", "Redstone", "Quartz" }
    for i = 1, 2 do
        for j = 1, 2 do
            local name = keys[(i - 1) * 2 + j]
            local mat = materials[name]
            local y = 1 + i * 2
            local x = (j - 1) * math.floor(screen_w / 2) + 1
            monitor.setCursorPos(x, y)
            monitor.setTextColor(get_percent_color(mat.percent))
            monitor.write(string.format("%s : %d%%", name, mat.percent))
            monitor.setCursorPos(x, y + 1)
            monitor.setTextColor(colors.white)
            monitor.write(string.format("%d / %d", mat.count, mat.limit))
        end
    end
end

local function draw_logs()
    local offset = 6
    for i, entry in ipairs(log_lines) do
        monitor.setCursorPos(1, i + offset)
        monitor.setTextColor(color_time)
        monitor.write("[" .. entry.time .. "] ")

        monitor.setTextColor(color_sender)
        monitor.write("[" .. entry.sender .. "] ")

        monitor.setTextColor(level_colors[entry.level] or colors.white)
        monitor.write(entry.msg)
    end
end

local function draw_buttons()
    local start_stop_label = is_running and "[ STOP ]" or "[ START ]"
    local start_stop_x = math.floor((screen_w - #start_stop_label) / 2) + 1
    monitor.setCursorPos(start_stop_x, screen_h)
    monitor.setBackgroundColor(is_running and colors.red or colors.green)
    monitor.setTextColor(colors.white)
    monitor.write(start_stop_label)

    local trace_label = debug_trace and "[TRACE ✓]" or "[TRACE ×]"
    monitor.setCursorPos(screen_w - #trace_label + 1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write(trace_label)

    local clear_label = "[CLEAR]"
    monitor.setCursorPos(1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write(clear_label)
end

local function redraw_all()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    draw_top_section()
    draw_logs()
    draw_buttons()
end

-- === Logging and Input ===
local function clear_logs()
    log_lines = {}
    redraw_all()
end

local function send_control(msg)
    network.send(config.ids.master, msg, config.protocols.control)
end

local function add_log(entry)
    if entry.level == "trace" and not debug_trace then return end
    table.insert(log_lines, entry)
    if #log_lines > log_area_height then
        table.remove(log_lines, 1)
    end
end

local function format_entry(sender, payload)
    return {
        time   = payload.time or os.date("%H:%M:%S"),
        sender = payload.source or config.names[sender] or ("ID " .. tostring(sender)),
        level  = payload.level or "info",
        msg    = payload.message or tostring(payload)
    }
end

local function handle_touch(x, y)
    if y == screen_h then
        local start_stop_label = is_running and "[ STOP ]" or "[ START ]"
        local start_stop_x = math.floor((screen_w - #start_stop_label) / 2) + 1

        if x >= start_stop_x and x < start_stop_x + #start_stop_label then
            local next_state = not is_running
            send_control(next_state and config.keywords.start or config.keywords.stop)
            is_running = next_state
            redraw_all()
        elseif x >= screen_w - 9 then
            debug_trace = not debug_trace
            redraw_all()
        elseif x >= 1 and x <= 7 then
            clear_logs()
        end
    end
end

-- === Listeners ===
local function listener()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == config.protocols.logs then
            if sender == config.ids.drawer_sky and msg.data then
                local d = msg.data
                materials["Skystone"] = {
                    percent = math.floor(d.percent + 0.5),
                    count   = d.count,
                    limit   = d.limit
                }
            elseif type(msg) == "table" and msg.source and msg.message then
                add_log(format_entry(sender, msg))
            elseif type(msg) == "string" then
                add_log({
                    time = os.date("%H:%M:%S"),
                    sender = config.names[sender] or ("ID " .. tostring(sender)),
                    level = "info",
                    msg = msg
                })
            end
            redraw_all()

        elseif proto == config.protocols.control then
            if msg == config.keywords.start then is_running = true
            elseif msg == config.keywords.stop then is_running = false end
            redraw_all()

        elseif proto == config.protocols.status and msg == config.keywords.ping then
            rednet.send(sender, config.keywords.pong, config.protocols.reply)
            add_log({
                time = os.date("%H:%M:%S"),
                sender = config.names[os.getComputerID()],
                level = "trace",
                msg = "Pong response sent to " .. sender
            })

        elseif proto == config.protocols.update then
            logging.trace("Updating shared files.")
            shell.run("fetch_modules.lua")
            config  = require("modules.config")
            logging = require("modules.logging")
            network = require("modules.network")
            redraw_all()
            network.send(config.ids.server, config.keywords.update, config.protocols.share)
        end
    end
end

-- === Launch ===
logging.prompt("Monitor started.")
parallel.waitForAny(
    function() while true do local _, _, x, y = os.pullEvent("monitor_touch") handle_touch(x, y) end end,
    listener
)
