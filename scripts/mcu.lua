--- Skyfarm Master Control Unit
--- Created by judea.
--- DateTime: 8/06/2025 1:24 am
---

--- Skyfarm Master Script
--- Updated for modular structure and shared configs
--- Created by judea.

-- === Shared Modules ===
package.path = "/modules/?.lua;" .. package.path
local config  = require("config")
local logging = require("logging")
local network = require("network")

-- === Shortcuts ===
local ids       = config.ids
local protocols = config.protocols
local kw        = config.keywords
local thresholds = config.thresholds

-- === State ===
local drill_state   = false
local pusher_lvl    = 1
local manual_stop   = false
local drawer_stop   = false
local farm_running  = false

-- === Plate Movement ===
local function move_block_pusher(target)
    if target == 1 then
        network.send(ids.pusher, 1)
        local _, new = network.waitForReply(kw.plate_moved, 2)
        pusher_lvl = new or pusher_lvl
    elseif target == 0 then
        local _, new = network.sendAndWait(ids.pusher, -15, kw.plate_grounded, 3)
        pusher_lvl = new or pusher_lvl
    end
end

-- === Controls ===
local function move_drills(reverse)
    if reverse then
        network.sendAndWait(ids.drill, kw.backward, kw.drill_full_back, 30)
    else
        network.sendAndWait(ids.drill, kw.forward, kw.drill_full_front, 30)
    end
end

local function toggle_drills()
    move_drills(not drill_state)
    drill_state = not drill_state
end

local function deploy()
    network.sendAndWait(ids.deployer, kw.deploy, kw.deploy_done, 5)
end

-- === Reset ===
local function reset()
    move_block_pusher(0)
    move_drills(true)
    drill_state = true
    sleep(2)
end

-- === Fill Level Check ===
local function update_drawer_fill_state()
    network.send(ids.drawer_sky, kw.fill, protocols.control)
    local _, response = rednet.receive(protocols.reply, 2)
    local fill = tonumber(response)
    if fill then
        drawer_stop = fill >= thresholds.sky_stop
    else
        logging.warn("Failed to get drawer fill level.")
    end
end

-- === Upward Sequence with Recovery ===
local function upward_plate_sequence_with_timeout()
    local timeout = 20
    local last_feedback_time = os.clock()

    while pusher_lvl < 15 do
        network.send(ids.pusher, 1)
        sleep(0.2)

        local _, new = network.waitForReply(kw.plate_moved, 3)
        if new then
            pusher_lvl = new
            last_feedback_time = os.clock()
            toggle_drills()
        elseif os.clock() - last_feedback_time > timeout then
            logging.warn("No LVL feedback in 20s. Lowering plate and restarting climb.")
            toggle_drills()
            network.waitForReply(drill_state and kw.drill_full_front or kw.drill_full_back, 2)
            network.send(ids.pusher, -1)
            local _, new2 = network.waitForReply(kw.plate_moved, 3)
            pusher_lvl = (new2 or pusher_lvl) - 1
            toggle_drills()
            last_feedback_time = os.clock()
        end
    end
end

-- === Farm Cycle ===
local function farm_cycle()
    if farm_running or manual_stop or drawer_stop then return end
    farm_running = true

    local start_time = os.clock()
    local fallback_count = 0

    logging.info("Starting farm cycle.")
    deploy()
    sleep(6)

    -- Blind climb to LVL 5
    local reached_lv5 = false
    while not reached_lv5 do
        local climb_start = os.clock()
        while os.clock() - climb_start < 7 do
            move_block_pusher(1)
            sleep(0.5)
            if pusher_lvl >= 5 then
                reached_lv5 = true
                break
            end
        end
        if not reached_lv5 then
            logging.warn("Didn't reach LVL 5 in time. Moving down 1 block.")
            fallback_count = fallback_count + 1
            network.send(ids.pusher, -1)
            sleep(1.5)
        end
    end

    logging.info("Reached LVL 5. Beginning drill-assisted ascent.")
    upward_plate_sequence_with_timeout()

    logging.info("Cycle finished. Resetting.")
    reset()

    local duration = os.clock() - start_time
    logging.info("Cycle Duration: " .. string.format("%.1f", duration) .. "s")
    logging.info("Final Plate LVL: " .. pusher_lvl)
    logging.info("Drill Direction : " .. (drill_state and "Forward" or "Backward"))
    logging.info("Fallback Count  : " .. fallback_count)

    logging.info("Cycle complete. Ready for next.")
    farm_running = false
end

-- === Control Listener ===
local function listening()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == protocols.control then
            if msg == config.keywords.stop then
                if sender == ids.monitor then
                    manual_stop = true
                    logging.warn("Manual stop triggered.")
                end
            elseif msg == config.keywords.start then
                if sender == ids.monitor then
                    manual_stop = false
                    logging.info("Manual start triggered.")
                end
            end

        elseif proto == protocols.share and msg == kw.update then
            logging.trace("Updating shared files.")
            package.loaded["module.config"] = nil
            package.loaded["module.logging"] = nil
            package.loaded["module.network"] = nil
            package.loaded["module.utils"] = nil
            shell.run("fetch_modules.lua")
            config = require("module.config")
            logging = require("module.logging")
            network = require("module.network")
            utils = require("module.utils")
            logging.trace("Files updated.")
            network.send(config.ids.server,config.keywords.update, config.protocols.share)

        elseif proto == protocols.status and msg == kw.ping then
            rednet.send(sender, config.keywords.pong, config.protocols.reply)
            logging.trace("Pong response sent to " .. sender)
        end
    end
end

-- === Init ===
logging.info("Pinging nodes...")
for name, id in pairs(ids) do
    if type(id) == "number" and id ~= ids.monitor then
        local ok = network.ping(id, 2)
        logging[ok and "info" or "warn"](name .. (ok and " is online." or " did not respond."))
    end
end

logging.info("=== Initial State ===")
logging.info("Manual Stop Flag  : " .. tostring(manual_stop))
logging.info("Drawer Stop Flag  : " .. tostring(drawer_stop))
logging.info("Farm Running Flag : " .. tostring(farm_running))
logging.info("=====================")
logging.info("Resetting system...")
reset()

-- === Main ===
parallel.waitForAny(
    listening,
    function()
        while true do
            update_drawer_fill_state()

            if drawer_stop then
                logging.warn("Drawer is full. Waiting...")
                repeat
                    sleep(5)
                    update_drawer_fill_state()
                until not drawer_stop
                logging.info("Drawer ready. Resuming.")
            end

            if manual_stop then
                sleep(0.5)
            else
                farm_cycle()
            end

            sleep(0.5)
        end
    end
)

