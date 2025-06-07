--- Skyfarm Logging
--- Created by judea.
--- DateTime: 7/06/2025 4:42 pm
---

local config = require("config")

local function log(sender, msg, data)
    local time = os.date("%H:%M:%S")
    local label = sender or "master"
    print(("[" .. time .. "] " .. msg))
    rednet.send(config.ids.monitor, {
        source = label,
        time = time,
        message = msg,
        data = data
    }, config.protocols.logs)
end

return log