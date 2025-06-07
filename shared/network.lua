--- Skyfarm Network
--- Created by judea.
--- DateTime: 7/06/2025 4:43 pm
---

local config = require("config")

local function send(id, msg)
    rednet.send(id, msg, config.protocols.control)
end

local function waitForReply(keyword, timeout)
    local start = os.clock()
    repeat
        local _, msg = rednet.receive(timeout)
        if msg and msg:find(keyword) then
            local lvl = tonumber(string.match(msg, "LVL ?(%d+)"))
            return msg, lvl
        end
    until os.clock() - start > timeout
    return nil, nil
end

local function sendAndWait(id, msg, keyword, timeout)
    send(id, msg)
    return waitForReply(keyword, timeout)
end

local function ping(id, timeout)
    rednet.send(id, "ping", config.protocols.status)
    local start = os.clock()
    while os.clock() - start < timeout do
        local sender, message, protocol = rednet.receive(config.protocols.reply, timeout)
        if sender == id and message == "pong" then
            return true
        end
    end
    return false
end

return {
    send = send,
    waitForReply = waitForReply,
    sendAndWait = sendAndWait,
    ping = ping
}
