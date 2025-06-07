---
--- Created by judea.
--- DateTime: 7/06/2025 8:39 pm
---
-- === Load Modules ===
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")
local utils   = require("modules.utils")

-- === Test Logging ===
print("== Logging Module Test ==")
logging.info("This is an info log.")
logging.warn("This is a warning log.")
logging.error("This is an error log.")
logging.prompt("This is a prompt output.")


-- === Test Network ===
print("\n== Network Module Test ==")
local test_id = config.ids.server
local timeout = 3

local success = network.ping(test_id, timeout)
if success then
    logging.prompt("Ping to ID " .. test_id .. " successful.")
else
    logging.prompt("Ping to ID " .. test_id .. " failed.")
end


-- === Test Utils ===
local minval = utils.clamp(10,20,60)
local maxval = utils.clamp(70,20,60)

if minval == 20 then
    logging.prompt("Min clamp : " .. tostring(minval))
else
    logging.prompt("Error on minimum clamp")
end

if maxval == 60 then
    logging.prompt("Max clamp : " .. tostring(maxval))
else
    logging.prompt("Error on maximum clamp")
end


print("\n== All Modules Tested ==")
