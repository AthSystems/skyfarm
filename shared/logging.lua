--- Skyfarm Logging
--- Supports log, warn, and error levels via rednet broadcast
--- Created by judea.
--- DateTime: 7/06/2025 4:42 pm
---

--- Skyfarm Logging
--- Created by judea

local config = require("config")
local node_name = config.names[os.getComputerID()]
local is_master = os.getComputerID() == 1

-- === Monitor Setup (Master Only) ===
local monitor, lines, max_lines

if is_master then
    monitor = peripheral.find("monitor", function(name, obj)
        return peripheral.getType(name) == "monitor" and peripheral.getName(obj) == "left"
    end)

    if monitor then
        monitor.setTextScale(0.5)
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        lines = {}
        max_lines = select(2, monitor.getSize())
    end
end

-- === Level Colors ===
local level_colors = {
    trace = colors.lightGray,
    info = colors.white,
    warn = colors.yellow,
    error = colors.red
}

-- === Monitor Display (Master Only) ===
local function drawMonitor()
    if not monitor then return end

    monitor.clear()
    local height = select(2, monitor.getSize())
    local start = math.max(1, #lines - height + 1)

    for i = start, #lines do
        local entry = lines[i]
        monitor.setCursorPos(1, i - start + 1)

        monitor.setTextColor(colors.lime)
        monitor.write(entry.time .. " ")

        monitor.setTextColor(level_colors[entry.level] or colors.white)
        monitor.write(entry.msg)
    end
end

local function printToMonitor(level, msg)
    if not monitor then return end

    local time = os.date("%H:%M:%S")
    table.insert(lines, { time = time, msg = msg, level = level })
    if #lines > max_lines then
        table.remove(lines, 1)
    end
    drawMonitor()
end

-- === Local Prompt ===
local function prompt(msg)
    local time = os.date("%H:%M:%S")
    print(string.format("[%s] %s", time, msg))
    if is_master then
        printToMonitor("info", msg)
    end
end

-- === Main Logging ===
local function send_log(level, sender, msg, data)
    local time = os.date("%H:%M:%S")
    local label = sender or "unknown"

    local payload = {
        source = label,
        time = time,
        level = level,
        message = msg,
        data = data
    }

    -- Print locally
    print(string.format("[%s] [%s] %s", time, level:upper(), msg))

    -- Monitor output (Master only)
    if is_master then
        printToMonitor(level, string.format("[%s] %s", level:upper(), msg))
    end

    -- Broadcast to all
    rednet.broadcast(payload, config.protocols.logs)
end

-- === Logging Levels ===
local function trace(msg, data) send_log("trace", node_name, msg, data) end
local function info(msg, data)  send_log("info",  node_name, msg, data) end
local function warn(msg, data)  send_log("warn",  node_name, msg, data) end
local function error(msg, data) send_log("error", node_name, msg, data) end

return {
    trace = trace,
    info = info,
    warn = warn,
    error = error,
    prompt = prompt
}
