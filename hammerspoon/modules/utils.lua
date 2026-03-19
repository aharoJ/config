-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  utils.lua — Shared Hammerspoon Helpers                                    ║
-- ║  path: ~/.config/hammerspoon/modules/utils.lua                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local M = {}

local YABAI = "/opt/homebrew/bin/yabai"

--- Run a yabai query and return parsed JSON.
--- @param args string  e.g. "--windows --space"
--- @return table|nil   parsed result, or nil on failure
function M.yabaiQuery(args)
  local cmd = YABAI .. " -m query " .. args
  local output, status = hs.execute(cmd)
  if not status then
    return nil
  end
  local ok, result = pcall(hs.json.decode, output)
  if not ok then
    return nil
  end
  return result
end

--- Check if macOS is in dark mode.
--- @return boolean
function M.isDarkMode()
  return hs.host.interfaceStyle() == "Dark"
end

--- Create a debounced version of a function.
--- The function will only execute after `delay` seconds of inactivity.
--- @param fn function
--- @param delay number  seconds
--- @return function
function M.debounce(fn, delay)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
    end
    timer = hs.timer.doAfter(delay, function()
      fn(table.unpack(args))
    end)
  end
end

return M
