--- Skyfarm Monitor (Graphical UI + Logs)
--- Display farm status, materials, drill/plate state, timer, and logs
--- Created by judea

-- === Shared Modules ===
package.path = package.path .. ";/modules/?.lua"
local config  = require("modules.config")
local logging = require("modules.logging")
local network = require("modules.network")
local utils   = require("modules.utils")

-- === Setup ===
local modem = peripheral.find("modem") or error("No modem found")
rednet.open(peripheral.getName(modem))

local monitor = peripheral.find("monitor") or error("No monitor found")
monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.clear()
local screen_w, screen_h = monitor.getSize()

-- === State ===
local is_running = false
local debug_trace = false
local current_page = "overall"
local log_lines = {}
local log_area_height = screen_h - 3
local material_data = {
    Skystone = { percent = 0, count = 0, limit = 0, last = 0 },
    Certus = { percent = 0, count = 0, limit = 0, last = 0 },
    Redstone = { percent = 0, count = 0, limit = 0, last = 0 },
    Quartz = { percent = 0, count = 0, limit = 0, last = 0 }
}

local drill_back = false
local drill_front = false
local pusher_level = 1
local cycle_timer = 0

-- === Helper Functions ===
local function percent_color(p)
    if p < 30 then return colors.white
    elseif p < 60 then return colors.green
    elseif p < 90 then return colors.orange
    else return colors.red end
end

local function draw_square(x, y, size, fill)
    for dx = 0, size - 1 do
        for dy = 0, size - 1 do
            monitor.setCursorPos(x + dx, y + dy)
            monitor.write(fill and " " or "")
        end
    end
end

local function format_time(seconds)
    local min = math.floor(seconds / 60)
    local sec = math.floor(seconds % 60)
    return string.format("%02d:%02d", min, sec)
end

-- === Drawing ===
local function draw_overall_page()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Top: STATUS + Material Info
    monitor.setCursorPos(2, 1)
    monitor.setTextColor(colors.white)
    monitor.write("STATUS:")
    monitor.setTextColor(is_running and colors.lime or colors.orange)
    monitor.write(" " .. (is_running and "Running" or "Stopped"))

    local mat_names = { "Skystone", "Certus", "Redstone", "Quartz" }
    local spacing = math.floor(screen_w / 4)

    for i, name in ipairs(mat_names) do
        local m = material_data[name]
        local x = (i - 1) * spacing + 1
        monitor.setCursorPos(x, 2)
        monitor.setTextColor(percent_color(m.percent))
        monitor.write(string.format("%s: %d%%", name, m.percent))

        monitor.setCursorPos(x, 3)
        if m.count > m.last then
            monitor.setTextColor(colors.green)
        elseif m.count < m.last then
            monitor.setTextColor(colors.red)
        else
            monitor.setTextColor(colors.white)
        end
        monitor.write(string.format("%d/%d", m.count, m.limit))
    end

    -- Second line: Drill + Plate visual
    local plate_y = 5
    local bar_x = 10
    local bar_len = screen_w - 20
    local level_max = 15
    local filled_blocks = math.floor((pusher_level / level_max) * bar_len)

    -- Drill back square
    monitor.setBackgroundColor(drill_back and colors.yellow or colors.gray)
    draw_square(2, plate_y, 2, true)

    -- Drill front square
    monitor.setBackgroundColor(drill_front and colors.yellow or colors.gray)
    draw_square(screen_w - 3, plate_y, 2, true)

    -- Plate progress bar
    for i = 0, bar_len - 1 do
        local x = bar_x + i
        monitor.setCursorPos(x, plate_y)
        monitor.setBackgroundColor(i < filled_blocks and colors.orange or colors.gray)
        monitor.write(" ")
    end

    -- Timer
    monitor.setCursorPos(bar_x, plate_y + 1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.lime)
    monitor.write("Timer: " .. format_time(cycle_timer))

    -- Buttons (3rd line)
    local function button(x, label, bg, fg)
        monitor.setCursorPos(x, screen_h)
        monitor.setBackgroundColor(bg)
        monitor.setTextColor(fg or colors.white)
        monitor.write(label)
    end

    button(2, is_running and "[ STOP ]" or "[ START ]", is_running and colors.red or colors.green)
    button(screen_w - 8, "[ LOGS ]", colors.lightBlue)
end

local function draw_log_page()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    local offset = 1
    for i, entry in ipairs(log_lines) do
        if i > log_area_height then break end
        monitor.setCursorPos(1, i + offset)
        monitor.setTextColor(colors.lime)
        monitor.write("[" .. entry.time .. "] ")
        monitor.setTextColor(colors.orange)
        monitor.write("[" .. entry.sender .. "] ")
        monitor.setTextColor(level_colors[entry.level] or colors.white)
        monitor.write(entry.msg)
    end

    -- Buttons
    local function button(x, label, bg)
        monitor.setCursorPos(x, screen_h)
        monitor.setBackgroundColor(bg)
        monitor.setTextColor(colors.black)
        monitor.write(label)
    end
    button(2, "[CLEAR]", colors.lightGray)
    button(12, debug_trace and "[TRACE ✓]" or "[TRACE ×]", colors.lightGray)
    button(screen_w - 10, "[ FARM ]", colors.lightBlue)
end

local function redraw()
    if current_page == "overall" then
        draw_overall_page()
    else
        draw_log_page()
    end
end

-- === Event Handlers ===
local function handle_touch(x, y)
    if current_page == "overall" and y == screen_h then
        if x >= 2 and x <= 9 then
            is_running = not is_running
            network.send(config.ids.master, is_running and config.keywords.start or config.keywords.stop, config.protocols.control)
        elseif x >= screen_w - 8 then
            current_page = "logs"
        end
    elseif current_page == "logs" and y == screen_h then
        if x >= 2 and x <= 9 then
            log_lines = {}
        elseif x >= 12 and x <= 22 then
            debug_trace = not debug_trace
        elseif x >= screen_w - 10 then
            current_page = "overall"
        end
    end
    redraw()
end

-- === Listeners ===
local function listen()
    while true do
        local sender, msg, proto = rednet.receive()

        if proto == config.protocols.logs then
            if type(msg) == "table" and msg.source and msg.message then
                local entry = {
                    time = msg.time or os.date("%H:%M:%S"),
                    sender = msg.source or "unknown",
                    level = msg.level or "info",
                    msg = msg.message or tostring(msg)
                }
                if entry.level ~= "trace" or debug_trace then
                    table.insert(log_lines, entry)
                    if #log_lines > log_area_height then
                        table.remove(log_lines, 1)
                    end
                end
                redraw()
            end
        elseif proto == config.protocols.status and msg == config.keywords.ping then
            rednet.send(sender, config.keywords.pong, config.protocols.reply)
        elseif proto == config.protocols.control then
            if msg == config.keywords.start then
                is_running = true
            elseif msg == config.keywords.stop then
                is_running = false
            end
            redraw()
        elseif proto == config.protocols.data then
            if msg.materials then
                for name, data in pairs(msg.materials) do
                    if material_data[name] then
                        material_data[name].last = material_data[name].count
                        material_data[name].count = data.count
                        material_data[name].limit = data.limit
                        material_data[name].percent = data.percent
                    end
                end
                redraw()
            elseif msg.drill then
                drill_back = msg.drill.back
                drill_front = msg.drill.front
                redraw()
            elseif msg.pusher then
                pusher_level = msg.pusher.level
                cycle_timer = msg.pusher.timer or 0
                redraw()
            end
        end
    end
end

-- === Launch ===
logging.prompt("Monitor started.")
parallel.waitForAny(
    function()
        while true do
            local _, _, x, y = os.pullEvent("monitor_touch")
            handle_touch(x, y)
        end
    end,
    listen
)
