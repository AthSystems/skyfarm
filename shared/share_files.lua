--- Share files Script
--- Share files from server to client computers
--- Created by judea.
--- DateTime: 7/06/2025 4:44 pm
---

-- === Shared Module Server ===
local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local moduleNames = { "config", "logging", "network", "utils" }
local modules = {}

local function readModule(name)
    local path = name
    if fs.exists(path) then
        local f = fs.open(path, "r")
        local content = f.readAll()
        f.close()
        return content
    else
        print("⚠️  Module not found: " .. path)
        return nil
    end
end

-- Load all modules into memory
for _, name in ipairs(moduleNames) do
    local content = readModule(name)
    if content then
        modules[name] = content
    end
end

print("📡 Module server ready. Listening on protocol 'sky-share'.")
while true do
    local id, msg, protocol = rednet.receive("sky-share")
    if msg and modules[msg] then
        rednet.send(id, modules[msg], "sky-share")
    else
        rednet.send(id, nil, "sky-share")
    end
end
