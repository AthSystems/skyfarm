--- Drill End Course Sensor
--- Created by judea.
--- DateTime: 7/06/2025 11:03 pm
---
-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Per-Node Configuration ===
local master_id = config.ids.master
local id = os.getComputerID()
local name = config.names[id]
local feedback_command = nil
local redstone_side = nil

if id == 2 then
    feedback_command = config.keywords.drill_full_front
    redstone_side = "right"
else
    feedback_command = config.keywords.drill_full_back
    redstone_side = "left"
end

-- === State ===
local last_redstone_state = false

-- === Functions ===

-- Watch redstone input and send feedback on rising edge
local function watchRedstone()
    while true do
        os.pullEvent("redstone")
        local state = redstone.getInput(redstone_side)

        if state and not last_redstone_state then
            network.send(master_id, feedback_command, config.protocols.reply)
            logging.trace(name .. ":" .. feedback_command)
        end

        last_redstone_state = state
    end
end

-- Respond to ping messages
local function listening()
    while true do
        local sender, msg, protocol = rednet.receive()

        if protocol == config.protocols.status then
            if msg == config.keywords.ping then
                logging.trace("Ping received from" .. config.names[sender] .. ".")
                rednet.send(sender, config.keywords.pong, config.protocols.reply)
                logging.trace("Pong response sent to " .. sender)

            elseif msg == config.keywords.drill_full_back and id ~= 2  then
                rednet.send(config.ids.master, redstone.getInput(redstone_side), config.protocols.reply)
                logging.trace("Sending drill direction state : " .. tostring(redstone.getInput(redstone_side)))
            end

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
        end
    end
end

-- === Start ===
logging.prompt(name .. " ready. Listening on " .. redstone_side)
parallel.waitForAny(watchRedstone, listening)
