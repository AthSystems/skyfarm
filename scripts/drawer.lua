--- Skyfarm Skystone Monitoring
--- Created by judea.
--- DateTime: 7/06/2025 10:46 pm
---
-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Metadata ===
local item_name = "Skystone"
local drawer_side = "back"
local drawer = peripheral.wrap(drawer_side) or error("No drawer found on " .. drawer_side)
local slot = 1
local id = os.getComputerID()
local name = config.names[id]

-- === Drawer Data Reader ===
local function getDrawerData()
    local item = drawer.getItemDetail(slot)
    if not item then return {
        source = name,
        item = item_name,
        count = 0,
        limit = drawer.getItemLimit(slot),
        percent = 0.0
    } end

    local count = item.count
    local limit = drawer.getItemLimit(slot)
    local percent = (count / limit) * 100

    return {
        source  = name,
        item    = item_name,
        count   = count,
        limit   = limit,
        percent = percent
    }
end

-- === Periodic Logging to Monitor ===
local function monitorDrawer()
    while true do
        local data = getDrawerData()
        if data then
            logging.info("Skystone: " .. string.format("%.2f", data.percent) .. "% | " .. tostring(data.count) .. "/" .. tostring(data.limit), data)
        end
        sleep(5)
    end
end

-- === Command Listener ===
local function listen()
    while true do
        local sender, msg, protocol = rednet.receive()

        if protocol == config.protocols.status and msg == config.keywords.ping then
            network.send(sender, config.keywords.pong, config.protocols.reply)

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

        elseif protocol == config.protocols.control and msg == config.keywords.fill then
            local data = getDrawerData()
            if data then
                network.send(sender, tostring(data.percent), config.protocols.reply)
            end
        end
    end
end

-- === Startup ===
logging.info(name .. " ready")
parallel.waitForAll(monitorDrawer, listen)
