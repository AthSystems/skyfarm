local monitor = peripheral.find("monitor")
if not monitor then
  print("No monitor found")
  return
end

monitor.setTextScale(0.5)
term.redirect(monitor)
term.clear()

-- Size of each virtual 1x1 monitor slot
local slotWidth = 26
local slotHeight = 20

-- Base GitHub URL for fallback downloads
local baseURL = "https://raw.githubusercontent.com/AthSystems/skyfarm/refs/heads/main/images/"

-- Image layout and names
local positions = {
  { name = "redstone", x = 0, y = 0 },
  { name = "quartz", x = 1, y = 0 },
  { name = "sky_dust", x = 2, y = 0 },
  { name = "certus", x = 3, y = 0 }
}

-- Function to check and download if needed
local function ensureImage(name)
  local path = "images/" .. name .. ".nfp"
  shell.run("rm "..path)
  if not fs.exists(path) then
    print("Downloading: " .. name)
    local response = http.get(baseURL .. name .. ".nfp")
    if response then
      local content = response.readAll()
      response.close()
      fs.makeDir("images")
      local file = fs.open(path, "w")
      file.write(content)
      file.close()
    else
      print("Failed to download: " .. name)
      return false
    end
  end
  return true
end

-- Draw all images
for _, item in ipairs(positions) do
  if ensureImage(item.name) then
    local image = paintutils.loadImage("images/" .. item.name .. ".nfp")
    if image then
      local drawX = item.x * slotWidth + 1
      local drawY = item.y * slotHeight + 1
      paintutils.drawImage(image, drawX, drawY)
    else
      print("Invalid image format: " .. item.name)
    end
  end
end

term.setCursorPos(1, 100)
print("Done.")
