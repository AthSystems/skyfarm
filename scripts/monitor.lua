--- Skyfarm Monitor
--- Updated for structured payload, log level filter, and modular config
--- DateTime: 7/06/2025

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
local log_area_height = screen_h - 2

-- === Color Settings ===
local color_time   = colors.lime
local color_sender = colors.orange

local level_colors = {
    trace = colors.lightGray,
    info  = colors.white,
    warn  = colors.yellow,
    error = colors.red
}

-- === UI Drawing ===
local function redraw_logs()
    monitor.setBackgroundColor(colors.black)
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

    -- === Buttons ===
    -- Start/Stop (center)
    local start_stop_label = is_running and "[ STOP ]" or "[ START ]"
    local start_stop_x = math.floor((screen_w - #start_stop_label) / 2) + 1
    monitor.setCursorPos(start_stop_x, screen_h)
    monitor.setBackgroundColor(is_running and colors.red or colors.green)
    monitor.setTextColor(colors.white)
    monitor.write(start_stop_label)

    -- Trace Toggle (right)
    local trace_label = debug_trace and "[TRACE ✓]" or "[TRACE ×]"
    monitor.setCursorPos(screen_w - #trace_label + 1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write(trace_label)

    -- Clear Button (left)
    local clear_label = "[CLEAR]"
    monitor.setCursorPos(1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write(clear_label)
end

local function clear_logs()
    log_lines = {}
    redraw_logs()
end

local function send_control(msg)
    local master_id = config.ids.master or 1
    network.send(master_id, msg, config.protocols.control)
end

-- === Logging Handler ===
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

-- === Event Handlers ===
local function handle_touch(x, y)
    if y == screen_h then
        local start_stop_label = is_running and "[ STOP ]" or "[ START ]"
        local start_stop_x = math.floor((screen_w - #start_stop_label) / 2) + 1

        -- Start/Stop button
        if x >= start_stop_x and x < start_stop_x + #start_stop_label then
            local next_state = not is_running
            send_control(next_state and config.keywords.start or config.keywords.stop)
            is_running = next_state
            redraw_logs()

        -- TRACE toggle
        elseif x >= screen_w - 9 then
            debug_trace = not debug_trace
            redraw_logs()

        -- CLEAR
        elseif x >= 1 and x <= 7 then
            clear_logs()
        end
    end
end


local function listening()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == config.protocols.logs then
            if type(msg) == "table" and msg.source and msg.message then
                local entry = format_entry(sender, msg)
                add_log(entry)
                redraw_logs()
            elseif type(msg) == "string" then
                add_log({
                    time = os.date("%H:%M:%S"),
                    sender = config.names[sender] or ("ID " .. tostring(sender)),
                    level = "info",
                    msg = msg
                })
                redraw_logs()
            end

        elseif proto == config.protocols.control then
            if msg == config.keywords.start then
                is_running = true
                redraw_logs()
            elseif msg == config.keywords.stop then
                is_running = false
                redraw_logs()
            end

        elseif proto == config.protocols.status then
            if msg == config.keywords.ping then
                rednet.send(sender, config.keywords.pong, config.protocols.reply)
                add_log({
                    time = os.date("%H:%M:%S"),
                    sender = config.names[os.getComputerID()],
                    level = trace,
                    msg = "Pong response sent to " .. sender
                })
            else
                add_log({
                    time = os.date("%H:%M:%S"),
                    sender = config.names[sender] or ("ID " .. tostring(sender)),
                    level = "info",
                    msg = msg
                })
                redraw_logs()
            end

        elseif proto == config.protocols.update then
            logging.trace("Updating shared files.")
            package.loaded["module.config"] = nil
            package.loaded["module.logging"] = nil
            package.loaded["module.network"] = nil
            package.loaded["module.utils"] = nil
            shell.run("fetch_modules.lua")
            config = require("module.config")
            logging = require("module.logging")
            network = require("module.network")
            utils = require("module.utils")
            logging.trace("Files updated.")
            network.send(config.ids.server,config.keywords.update, config.protocols.share)
        end
    end
end

-- === Launch ===
logging.prompt("Monitor started.")
parallel.waitForAny(
    function()
        while true do
            local _, _, x, y = os.pullEvent("monitor_touch")
            handle_touch(x, y)
        end
    end,
    listening
)
