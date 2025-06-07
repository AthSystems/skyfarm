--- Share files Script
--- Share files from server to client computers
--- Created by judea.
--- DateTime: 7/06/2025 4:44 pm
---

local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local modules = {
    config = "config",
    logging = "logging",
    network = "network",
    utils = "utils"
}

for k, v in pairs(modules) do
    modules[k] = textutils.unserialize(v) or v
end

print("📡 Module server ready.")
while true do
    local id, msg, protocol = rednet.receive("sky-share")
    if msg and modules[msg] then
        rednet.send(id, modules[msg], "sky-share")
    else
        rednet.send(id, nil, "sky-share")
    end
end