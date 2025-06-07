---
--- Created by judea.
--- DateTime: 7/06/2025 4:55 pm
---

-- === Shared Module Updater ===
local shared_server_id = 1 -- ID of the module server
local protocol = "sky-share"
local required_modules = { "config", "logging", "network", "utils" }

local function openModem()
    if rednet.isOpen() then return end
    local modem = peripheral.find("modem") or error("No modem found")
    rednet.open(peripheral.getName(modem))
end

local function updateModule(name)
    rednet.send(shared_server_id, name, protocol)
    local id, data = rednet.receive(protocol, 2)
    if data then
        local file = fs.open(name .. ".lua", "w")
        file.write(data)
        file.close()
        print("✅ Updated module:", name)
    else
        print("❌ Failed to update module:", name)
    end
end

local function updateAllModules()
    for _, mod in ipairs(required_modules) do
        print("🔄 Updating module:", mod)
        updateModule(mod)
    end
end

-- === Run Update ===
openModem()
updateAllModules()
print("✅ All shared modules updated.")
