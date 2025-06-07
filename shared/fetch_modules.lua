--- Shared Bootstrap
--- Download required scripts for Skyfarm project
--- Created by judea.
--- DateTime: 7/06/2025 4:51 pm
---

-- === Shared Module Bootstrap ===
local shared_server_id = 28 -- ID of the module server
local protocol = "sky-share"
local required_modules = { "config", "logging", "network", "utils" }

local function openModem()
    if rednet.isOpen() then return end
    local modem = peripheral.find("modem") or error("No modem found")
    rednet.open(peripheral.getName(modem))
end

local function fetchModule(name)
    rednet.send(shared_server_id, name, protocol)
    local id, data = rednet.receive(protocol, 2)
    if data then
        local file = fs.open(name .. ".lua", "w")
        file.write(data)
        file.close()
        print("✅ Module downloaded:", name)
    else
        print("❌ Failed to fetch module:", name)
    end
end

local function fetchAllModules()
    for _, mod in ipairs(required_modules) do
        if not fs.exists(mod .. ".lua") then
            print("📦 Fetching module:", mod)
            fetchModule(mod)
        else
            print("🟩 Module already present:", mod)
        end
    end
end

-- === Run Bootstrap ===
openModem()
fetchAllModules()

print("✅ All modules fetched.")
print("🔁 You can now create or run your main.lua program.")

