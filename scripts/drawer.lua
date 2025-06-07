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
local drawer_side = "back"
local drawer = peripheral.wrap(drawer_side) or error("No drawer found on " .. drawer_side)
local slot = 1
local id = os.getComputerID()
local name = config.names[id]

-- === Drawer Data Reader ===
local function getDrawerData()
    local item = drawer.getItemDetail(slot)
    if not item then return nil end

    local count = item.count
    local limit = drawer.getItemLimit(slot)
    local percent = (count / limit) * 100

    return {
        source  = name,
        item    = item.displayName,
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
            --network.send(config.ids.monitor, data, config.protocols.logs)
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
            sleep(10)
            shell.run("fetch_modules.lua")

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
