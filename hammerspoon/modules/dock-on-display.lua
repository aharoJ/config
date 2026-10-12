-- path: ~/.config/hammerspoon/modules/dock-on-display.lua
-- description: reset Dock after a debounced change in connected screen identities
-- date: 2026-10-12

local M = {}
local utils = require("modules.utils")

local function screenSet()
  local identities = {}
  for _, screen in ipairs(hs.screen.allScreens()) do
    identities[#identities + 1] = screen:getUUID() or tostring(screen:id())
  end
  table.sort(identities)
  return tostring(#identities) .. ":" .. table.concat(identities, ",")
end

function M.init()
  if M.watcher then return end
  local previous = screenSet()
  local changed = utils.debounce(function()
    local current = screenSet()
    if current == previous then return end
    previous = current
    M.task = hs.task.new("/usr/bin/killall", function(code, _, stderr)
      M.task = nil
      if code == 0 then
        print("[dock-on-display] Dock reset after screen-set change")
      else
        print("[dock-on-display] Dock reset failed: " .. tostring(code) .. " " .. stderr)
      end
    end, { "Dock" })
    if not M.task or not M.task:start() then
      M.task = nil
      print("[dock-on-display] Could not start killall Dock")
    end
  end, 3)
  M.watcher = hs.screen.watcher.new(changed):start()
end

return M
