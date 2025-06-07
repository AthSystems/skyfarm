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

local function updateModule(name)
    local path = name .. ".lua"
    shell.run("rm ".. path)
    shell.run("wget https://github.com/AthSystems/skyfarm/raw/refs/heads/main/shared/" .. path .. " " .. path)
end

for _, name in ipairs(moduleNames) do
    updateModule(name)
end

local config = require("config")

for _, id in ipairs(config.ids) do
    rednet.send(id, config.keywords.update, config.protocols.share)
end

print("[V] Module server ready. Listening on protocol 'sky-share'.")
while true do
    local id, msg, protocol = rednet.receive()

    if protocol == config.protocols.status then
        if msg == "ping" then
            rednet.send(id, config.keywords.pong, config.protocols.reply)
        end
    elseif protocol == config.protocols.share then
        if msg and modules[msg] then
            rednet.send(id, modules[msg], config.protocols.share)
        else
            rednet.send(id, nil, config.protocols.share)
        end
    end
end
