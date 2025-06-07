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
    if fs.exists(path) then
            local f = fs.open(path, "r")
            local content = f.readAll()
            f.close()
            return content
        else
            print("⚠️  Module not found: " .. path)
            return nil
    end
end

for _, name in ipairs(moduleNames) do
    local content  = updateModule(name)
    if content then
        modules[name] = content
end

local config = require("config")
local logging = require("logging")
local network = require("network")

for _, id in ipairs(config.ids) do
    network.send(id, config.keywords.update, config.protocols.share)
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
            logging.prompt("Receive share request from " .. config.names[id] .. ". Sent " .. msg .. "module.")
        else
            rednet.send(id, nil, config.protocols.share)
            logging.prompt("Receive share request from " .. config.names[id] .. ". Module " .. msg .. " failed.")
        end
    end
end
