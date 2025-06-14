--- Skyfarm Pusher Actuator
--- Created by judea.
--- DateTime: 7/06/2025 10:30 pm
---

-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Metadata ===
local max_speed = 2
local direction_mod = 1
local id = os.getComputerID()
local name = config.names[id]

-- === Peripheral Setup ===
local gearshift = peripheral.wrap("bottom") or error("No gearshift on bottom", 0)
local speedo = peripheral.wrap("left")


local function getMaxSpeed()
    if math.abs(speedo.getSpeed()) < 128 then return 2 else return 1 end
end

local function getDirectionMod()
    if speedo.getSpeed() < 0 then return -1 else return 1 end
end

local function getSpeed()
    return getMaxSpeed() * getDirectionMod()
end


-- === Optional Startup Reset ===
gearshift.move(15, -getSpeed())
logging.info(name .. " initialized with reset.")


-- === Main Loop ===
while true do
    local senderID, msg, protocol = rednet.receive()

    -- === Ping Handling ===
    if protocol == config.protocols.status and msg == config.keywords.ping then
        logging.prompt("Ping received from ID " .. senderID)
        network.send(senderID, config.keywords.pong, config.protocols.reply)
        logging.trace(name .. ": " .. config.keywords.pong)

    -- Module update handling
    elseif protocol == config.protocols.share and msg == config.keywords.update then
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


    -- === Control Handling ===
    elseif protocol == config.protocols.control then
        logging.trace("Command received: " .. tostring(msg))

        local length = tonumber(msg)
        if length then
            local speed = (length < 0) and -getSpeed() or getSpeed()
            gearshift.move(length, speed)

            local feedback = "Set plate to " .. tostring(length)
            logging.trace(name .. ": " .. feedback)
        else
            local error_msg = "Invalid pusher command: " .. tostring(msg)
            network.send(senderID, error_msg, config.protocols.reply)
            logging.error(name .. ": " .. error_msg)
        end
    end
end
