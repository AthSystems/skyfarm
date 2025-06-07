--- Share files Script
--- Share files from server to client computers
--- Created by judea.
--- DateTime: 7/06/2025 4:44 pm
---

-- === Shared Module Server ===
local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local moduleNames = { "config", "logging", "network", "utils" }
local modules = {}

local function readModule(name)
    local path = name .. ".lua"
    if fs.exists(path) then
        local f = fs.open(path, "r")
        local content = f.readAll()
        f.close()
        print("[V] Module found: " .. path)
        return content
    else
        print("[X] Module not found: " .. path)
        return nil
    end
end

-- Load all modules into memory
for _, name in ipairs(moduleNames) do
    local content = readModule(name)
    if content then
        modules[name] = content
    end
end

local config = require("config")

print("[V] Module server ready. Listening on protocol 'sky-share'.")
while true do
    local id, msg, protocol = rednet.receive()

    if protocol == config.protocols.status then
        if msg == "ping" then
            rednet.send(id, "pong", config.protocols.reply)
        end
    elseif protocol == config.protocols.share then
        if msg and modules[msg] then
            rednet.send(id, modules[msg], config.protocols.share)
        else
            rednet.send(id, nil, config.protocols.share)
        end
    end
end
