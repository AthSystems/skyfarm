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
local page_overview = "overview"
local page_logs = "logs"
local current_page = page_overview
local log_lines = {}
local log_area_height = screen_h - 3

local spacing = math.floor(screen_w / 4)
local material_data = {
    Skystone = { percent = 0, count = 0, limit = 0, last = 0 , x = 1, l = #("Skystone: 100 %")},
    Certus = { percent = 0, count = 0, limit = 0, last = 0, x = 1 + spacing, l = #("Certus: 100 %")},
    Redstone = { percent = 0, count = 0, limit = 0, last = 0, x = 1 + 2 * spacing, l = #("Redstone: 100 %") },
    Quartz = { percent = 0, count = 0, limit = 0, last = 0, x = 1 + 3 * spacing, l = #("Quartz: 100 %")}
}

local level_colors = {
    trace = colors.lightGray,
    info  = colors.white,
    warn  = colors.yellow,
    error = colors.red
}


local plate_y = 14
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

local function draw_square(x_start, y_start, x_end, y_end, fill, color)
    if fill then
        paintutils.drawFilledBox(x_start, y_start, x_end, y_end, color)
    else
        paintutils.drawBox(x_start, y_start, x_end, y_end, color)
    end
end

local function format_time(seconds)
    local min = math.floor(seconds / 60)
    local sec = math.floor(seconds % 60)
    return string.format("%02d:%02d", min, sec)
end
local function format_number(n)
    if n >= 1000000000 then
        return string.format("%.1fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

local function add_entry(msg)
    if msg.source and msg.message then
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
    end
end
-- === Drawing ===

local function clearScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local function clearRegion(x_start, y_start, x_end, y_end)
    draw_square(x_start, y_start, x_end, y_end, true, colors.black)
end

local function draw_status()
    if not current_page == page_overview then return end
    clearRegion(0, 1, screen_w, 1)
    local status_text = "STATUS: " .. (is_running and "Running" or "Stopped")
    monitor.setCursorPos(screen_w/2 - #status_text/2, 1)
    monitor.setTextColor(colors.white)
    monitor.write("STATUS:")
    monitor.setTextColor(is_running and colors.lime or colors.orange)
    monitor.write(" " .. (is_running and "Running" or "Stopped"))
end

local function draw_material(name)
    if not current_page == page_overview then return end
    local m = material_data[name]
    local bottom_string = format_number(m.count) .. "/ " .. format_number( m.limit)

    clearRegion(m.x, 2, m.x + m.l, 3)

    monitor.setCursorPos(m.x, 2)
    monitor.setTextColor(percent_color(m.percent))
    monitor.write(string.format("%s: %d%%", name, m.percent))


    monitor.setCursorPos(m.x + m.l/2 - #bottom_string/2, 3)
    if m.count > m.last then
        monitor.setTextColor(colors.green)
    elseif m.count < m.last then
        monitor.setTextColor(colors.red)
    else
        monitor.setTextColor(colors.white)
    end
    monitor.write(format_number(m.count))
    monitor.setTextColor(colors.white)
    monitor.write("/ " .. format_number( m.limit))
end

local function draw_drill()
    if not current_page == page_overview then return end

    -- Drill back square
    clearRegion(2, plate_y,3, plate_y+1)
    draw_square(2, plate_y, 3, plate_y+1,  drill_back, drill_back and colors.yellow or colors.gray)

    -- Drill front square
    clearRegion(screen_w - 3, plate_y,screen_w - 2, plate_y+1)
    draw_square(screen_w - 3, plate_y, screen_w - 2, plate_y+1, drill_front, drill_front and colors.yellow or colors.gray)
end

local function draw_plate_bar()
    if not current_page == page_overview then return end
    local bar_x = 10
    local bar_len = screen_w - 20
    local level_max = 15
    local filled_blocks = math.floor((pusher_level / level_max) * bar_len)

    clearRegion(bar_x, plate_y,bar_x + bar_len, plate_y+1)

    draw_square(bar_x, plate_y, bar_x + bar_len, plate_y + 1, false, colors.gray)
    draw_square(bar_x, plate_y, bar_x + filled_blocks, plate_y+1, true, colors.yellow)

end

local function draw_timer()
    local str_time = format_time(cycle_timer)

    -- Timer
    monitor.setCursorPos(screen_w/2 - #("Timer: " .. str_time), plate_y + 2)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.write("Timer: ")
    monitor.setTextColor(colors.lime)
    monitor.write(str_time)
end

local function button(x, label, bg, fg)
    monitor.setTextScale(2)
    monitor.setCursorPos(x, screen_h)
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(fg or colors.white)
    monitor.write(label)
end

local function draw_overall_page()
    clearScreen()

    -- Status
    draw_status()

    -- Materials
    for k, _ in pairs(material_data) do
        draw_material(k)
    end

    -- Drills and Plate
    draw_plate_bar()
    draw_drill()

    -- Cycle Timer
    draw_timer()

    -- Buttons
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
    if current_page == page_overview then
        draw_overall_page()
    else
        draw_log_page()
    end
end

-- === Event Handlers ===

local function timer()
    while true do
        sleep(1)
        cycle_timer = cycle_timer + 1
        draw_timer()
    end
end

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

            if type(msg) == "table" then
                -- Material Data Handling - Skystone

                if sender == config.ids.drawer_sky then
                    material_data[msg.data.item].last = material_data[msg.data.item].count
                    material_data[msg.data.item].count = msg.data.count
                    material_data[msg.data.item].limit = msg.data.limit
                    material_data[msg.data.item].percent = msg.data.percent
                    add_entry(msg)
                    if current_page == page_overview then draw_material(msg.item.data) else redraw() end

                -- Drill Position Handling
                elseif sender == config.ids.dff or sender == config.ids.dfb then
                    if sender == config.ids.dfb then
                        drill_back = true
                        drill_front = false
                    else
                        drill_back = false
                        drill_front = true
                    end
                    add_entry(msg)
                    if current_page == page_overview then draw_drill() else redraw() end

                -- Plate Position Handling
                elseif msg.message:find("LVL") then
                    local level = tonumber(msg.data)
                    pusher_level = level
                    add_entry(msg)
                    if current_page == page_overview then draw_plate_bar() else redraw() end

                -- Cycle Timer Handling
                elseif sender == config.ids.master then
                    if msg.message:find("Starting") then
                        cycle_timer = 0
                    end
                    add_entry(msg)
                    if current_page == page_overview then draw_timer() else redraw() end
                else
                    add_entry(msg)
                    redraw()
                end
            end

        elseif proto == config.protocols.status and msg == config.keywords.ping then
            rednet.send(sender, config.keywords.pong, config.protocols.reply)

        elseif proto == config.protocols.control then
            if msg == config.keywords.start then
                is_running = true
            elseif msg == config.keywords.stop then
                is_running = false
            end
            draw_status()

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
    listen,
    timer
)
