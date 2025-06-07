--- Skyfarm Drill Actuator
--- Created by judea.
--- DateTime: 7/06/2025 10:23 pm
---

-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Metadata ===
local controlledSide = "top"
local id = os.getComputerID()
local name = config.names[id]

-- === Ready Log ===
logging.info(name .. " ready")

-- === Main Loop ===
while true do
    local senderID, msg, protocol = rednet.receive()

    -- Ping handling
    if protocol == config.protocols.status and msg == config.keywords.ping then
        logging.prompt("Ping received from ID " .. senderID)
        network.send(senderID, config.keywords.pong, config.protocols.reply)
        logging.trace(name .. ": " .. config.keywords.pong)

    -- Module update handling
    elseif protocol == config.protocols.share and msg == config.keywords.update then
        sleep(10)
        shell.run("fetch_modules.lua")

    -- Drill control handling
    elseif protocol == config.protocols.control then
        if msg == config.keywords.forward then
            redstone.setOutput(controlledSide, false)
            logging.trace(name .. ": Moving forward")
        elseif msg == config.keywords.backward then
            redstone.setOutput(controlledSide, true)
            logging.trace(name .. ": Moving backward")
        end
    end
end
