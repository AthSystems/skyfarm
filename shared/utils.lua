--- Skyfarm Utils
--- Created by judea.
--- DateTime: 7/06/2025 8:11 pm
---
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

return {
    clamp = clamp
}
