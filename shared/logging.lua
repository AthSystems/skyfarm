--- Skyfarm Logging
--- Supports log, warn, and error levels via rednet broadcast
--- Created by judea.
--- DateTime: 7/06/2025 4:42 pm
---

local config = require("config")

-- Format & print message to local terminal
local function prompt(msg)
    local time = os.date("%H:%M:%S")
    print(string.format("[%s] %s", time, msg))
end

local function send_log(level, sender, msg, data)
    local time = os.date("%H:%M:%S")
    local label = sender or config.node_name or "unknown"

    local payload = {
        source = label,
        time = time,
        level = level,
        message = msg,
        data = data
    }

    -- Print locally
    print(string.format("[%s] [%s] %s", time, level:upper(), msg))

    -- Broadcast to all listening nodes
    rednet.broadcast(payload, config.protocols.logs)
end

local function log(msg, data)
    send_log("log", config.node_name, msg, data)
end

local function warn(msg, data)
    send_log("warn", config.node_name, msg, data)
end

local function error(msg, data)
    send_log("error", config.node_name, msg, data)
end

return {
    log = log,
    warn = warn,
    error = error
}
