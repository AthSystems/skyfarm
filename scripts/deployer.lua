--- Skyfarm Deployer Actuator
--- Created by judea.
--- DateTime: 7/06/2025 10:41 pm
---
-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Metadata ===
local gearshift_side = "back"
local speedo_side = "right"
local id = os.getComputerID()
local name = config.names[id]

-- === Peripheral Setup ===
local gearshift = peripheral.wrap(gearshift_side) or error("No gearshift on " .. gearshift_side)
local speedo = peripheral.wrap(speedo_side)


local function getMaxSpeed()
    if math.abs(speedo.getSpeed()) < 128 then return 2 else return 1 end
end

local function getDirectionMod()
    if speedo.getSpeed() > 0 then return -1 else return 1 end
end

local function getSpeed()
    return getMaxSpeed() * getDirectionMod()
end




-- === Motion Logic ===
local function move(length, direction)
    local real_speed = direction * getSpeed()
    gearshift.move(length, real_speed)
    logging.prompt("Moving " .. length .. " | direction: " .. tostring(direction))

    while gearshift.isRunning() do sleep(0.1) end
end

local function deploy()
    move(10,  1)
    for _ = 1, 3 do
        move(1, -1)
        move(1,  1)
    end
    move(10, -1)
end

-- === Startup ===
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

    -- Deploy handling
    elseif protocol == config.protocols.control and msg == config.keywords.deploy then
        logging.trace(name .. ": Deploy command received")
        redstone.setOutput("bottom", true)
        deploy()
        network.send(senderID, config.keywords.deploy_done, config.protocols.reply)
        logging.trace(name .. ": Deploy done.")
        sleep(5)
        redstone.setOut("bottom", false)
    end
end
