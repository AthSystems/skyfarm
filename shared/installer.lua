--- Skyfarm module installer
--- Created by judea.
--- DateTime: 7/06/2025 4:59 pm
---
-- === GitHub Base URL ===
local base_url = "https://github.com/AthSystems/skyfarm/raw/refs/heads/main/"

-- === Files to Download ===
local files = {
    {
        name = "fetch_modules.lua",
        folder = "shared/"
    },
    {
        name = "test_modules.lua",
        folder = "test/"
    }
}

-- === Download Files ===
for i, file in ipairs(files) do

    local response = http.get(base_url .. file[i].folder .. file[i].name)
    if response then
        local handle = fs.open(file[i].name, "w")
        handle.write(response.readAll())
        handle.close()
        response.close()
        print("[V] Downloaded: " .. file[i].name)
    else
        print("[X] Failed to download: " .. file[i].name)
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

shell.run("fetch_modules.lua")
shell.run("test_modules.lua")
]]

-- Save startup file at root
local startup = fs.open("startup.lua", "w")
startup.write(startup_code)
startup.close()

print("Startup configured to auto-install/update modules.")
