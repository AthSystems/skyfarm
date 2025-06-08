local monitor = peripheral.find("monitor")
if not monitor then
  print("Monitor not found")
  return
end

monitor.setTextScale(0.5)
term.redirect(monitor)
term.clear()

local imageNames = { "redstone", "quartz", "skystone", "certus" }
local x = 1
local y = 1

for _, name in ipairs(imageNames) do
  local path = "images/" .. name .. ".nfp"
  local image = paintutils.loadImage(path)
  if image then
    paintutils.drawImage(image, x, y)
    -- Move x to the right for next image (adjust 20 if needed)
    x = x + 20
  else
    print("Failed to load: " .. path)
  end
end

term.setCursorPos(1, y + 12)
print("All images drawn.")
