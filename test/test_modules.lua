---
--- Created by judea.
--- DateTime: 7/06/2025 8:39 pm
---
-- === Shared Module Usage Test ===
-- Assumes all modules are already saved in /modules/

-- Add modules folder to package.path if needed
package.path = "/modules/?.lua;" .. package.path

-- Require modules
local config = require("config")
local logging = require("logging")
local network = require("network")
local utils = require("utils")

-- Test each module
print("Testing shared modules...\n")

-- Config test
print("Config test:")
if config.node_id and config.node_name then
    print("[V] Node ID:", config.node_id)
    print("[V] Node Name:", config.node_name)
else
    print("[X] Config values not found.")
end

-- Logging test
print("\nLogging test:")
logging.log("This is a test log message from the client.")
logging.warn("This is a test warning.")
logging.error("This is a test error.")

-- Network test
print("\nNetwork test:")
print("Sending 'ping' to self...")
local ok = network.ping(config.node_id, 1)
print(ok and "[V] Ping successful." or "[X] Ping failed.")

-- Utils test
print("\nUtils test:")
print("Sleep for 1s with label:")
utils.sleep_with_label(1)

print("\n[V] All module functions tested.")


