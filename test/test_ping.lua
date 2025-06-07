---
--- Created by judea.
--- DateTime: 8/06/2025 1:10 am
---
--- Skyfarm Node Pinger
--- Sequentially pings all known nodes defined in config.ids

-- === Load Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")

-- === Setup Modem ===
if not rednet.isOpen() then
    local modem = peripheral.find("modem") or error("No modem found")
    rednet.open(peripheral.getName(modem))
end

-- === Ping All Nodes ===
local success = 0
local failed = 0
local total = #config.ids

for name, id in pairs(config.ids) do
    logging.info("Pinging [" .. name .. "] with ID " .. id)
    local ok = network.ping(id, 3)
    if ok then
        logging.info("Node [" .. name .. "] responded.")
        success = success + 1
    else
        logging.warn("Node [" .. name .. "] did not respond.")
        failed = failed +1
    end
    logging.info("Success: " .. tostring(success) .. " | Failed: " .. tostring(failed) .. " | Total:"  .. tostring(total) )
end

logging.prompt("All ping requests completed.")
