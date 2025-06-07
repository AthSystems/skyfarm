--- Skyfarm Deployer Actuator
--- Created by judea.
--- DateTime: 7/06/2025 10:41 pm
---
-- === Shared Modules ===
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Metadata ===
local gearshift_side = "back"
local max_speed = 2
local direction_mod = -1
local id = os.getComputerID()
local name = config.names[id]

-- === Peripheral Setup ===
local gearshift = peripheral.wrap(gearshift_side) or error("No gearshift on " .. gearshift_side)



function getSpeed()
    return max_speed * direction_mod
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
        sleep(10)
        shell.run("fetch_modules.lua")

    -- Deploy handling
    elseif protocol == config.protocols.control and msg == config.keywords.deploy then
        logging.trace(name .. ": Deploy command received")
        deploy()
        network.send(senderID, config.keywords.deploy_done, config.protocols.reply)
        logging.trace(name .. ": Deploy done.")
    end
end
