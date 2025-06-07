--- Skyfarm Monitor
--- Created by judea.
--- DateTime: 7/06/2025 11:31 pm
---
-- === Shared Modules ===
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
local function add_log(entry)
    if entry.level == "trace" and not debug_trace then return end
    table.insert(log_lines, entry)
    if #log_lines > log_area_height then
        table.remove(log_lines, 1)
    end
end

local function format_payload(sender, msg)
    return {
        time = msg.time or os.date("%H:%M:%S"),
        sender = config.names[sender] or ("ID " .. tostring(sender)),
        level = msg.level or "info",
        msg = msg.message or tostring(msg)
    }
end

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

    -- Trace (right)
    local trace_label = debug_trace and "[TRACE ✓]" or "[TRACE ×]"
    monitor.setCursorPos(screen_w - #trace_label + 1, screen_h)
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.write(trace_label)

    -- Clear (left)
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
    local master_id = config.ids.master or 1  -- fallback to 1 if not defined
    network.send(master_id, msg, config.protocols.control)
end


-- === Touch Events ===
local function handle_touch(x, y)
    if y == screen_h then
        local start_stop_label = is_running and "[ STOP ]" or "[ START ]"
        local start_stop_x = math.floor((screen_w - #start_stop_label) / 2) + 1

        -- Check Start/Stop
        if x >= start_stop_x and x < start_stop_x + #start_stop_label then
            is_running = not is_running
            send_control(is_running and config.keywords.start or config.keywords.stop)
            redraw_logs()
        -- Check TRACE
        elseif x >= screen_w - 9 then
            debug_trace = not debug_trace
            redraw_logs()
        -- Check CLEAR
        elseif x >= 1 and x <= 7 then
            clear_logs()
        end
    end
end

-- === Rednet Listener ===
local function handle_logs()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == config.protocols.logs then
            if type(msg) == "table" and msg.source and msg.level and msg.time and msg.message then
                -- Filter based on debug flag
                if msg.level == "trace" and not show_trace then
                    -- Skip trace if disabled
                else
                    table.insert(log_lines, {
                        time   = msg.time,
                        sender = msg.source,
                        level  = msg.level,
                        msg    = msg.message
                    })
                    if #log_lines > log_area_height then
                        table.remove(log_lines, 1)
                    end
                    redraw_logs()
                end
            elseif type(msg) == "string" then
                -- Fallback for legacy string logs
                table.insert(log_lines, {
                    time   = os.date("%H:%M:%S"),
                    sender = getName(sender),
                    level  = "info",
                    msg    = msg
                })
                if #log_lines > log_area_height then
                    table.remove(log_lines, 1)
                end
                redraw_logs()
            end

        elseif proto == config.protocols.control then
            if msg == config.keywords.stop then
                is_running = false
                redraw_logs()
            elseif msg == config.keywords.start then
                is_running = true
                redraw_logs()
            end

        elseif proto == config.protocols.status then
            table.insert(log_lines, {
                time   = os.date("%H:%M:%S"),
                sender = getName(sender),
                level  = "info",
                msg    = msg
            })
            if #log_lines > log_area_height then
                table.remove(log_lines, 1)
            end
            redraw_logs()
        end
    end
end


-- === Launch ===
parallel.waitForAny(
    handle_logs,
    function()
        while true do
            local _, _, x, y = os.pullEvent("monitor_touch")
            handle_touch(x, y)
        end
    end
)

logging.prompt("Monitor started.")
