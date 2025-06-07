--- Skyfarm module installer
--- Created by judea.
--- DateTime: 7/06/2025 4:59 pm
---
-- === GitHub Base URL ===
local base_url = "https://github.com/AthSystems/skyfarm/raw/refs/heads/main/shared/"

-- === Files to Download ===
local files = {
    "fetch_modules.lua",
    "update_modules.lua"
}

-- === Download Files ===
for _, file in ipairs(files) do
    local response = http.get(base_url .. file)
    if response then
        local handle = fs.open(file, "w")
        handle.write(response.readAll())
        handle.close()
        response.close()
        print("[V] Downloaded: " .. file)
    else
        print("[X] Failed to download: " .. file)
    end
end

-- === Setup Startup Behavior ===
local startup_code = [[
-- Auto-install or update shared modules
local modules = {
    "config.lua",
    "network.lua",
    "logging.lua",
    "utils.lua"
}

local allExist = true
for _, m in ipairs(modules) do
    if not fs.exists("shared/" .. m) then
        allExist = false
        break
    end
end

if allExist then
    shell.run("update_modules.lua")
else
    shell.run("fetch_modules.lua")
end
]]

-- Save startup file at root
local startup = fs.open("startup.lua", "w")
startup.write(startup_code)
startup.close()

print("Startup configured to auto-install/update modules.")
