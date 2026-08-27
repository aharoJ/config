-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  utils.lua — Shared Hammerspoon Helpers                                    ║
-- ║  path: ~/.config/hammerspoon/modules/utils.lua                             ║
-- ║  description: yabai query wrapper, dark-mode probe, debounce helper        ║
-- ║  patched: EAGAIN nil-guard around hs.execute (fork-exhaustion safety)      ║
-- ║  date: 2026-08-26                                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local M = {}

local YABAI = "/opt/homebrew/bin/yabai"

-- Latched so a sustained failure (e.g. process-table exhaustion) logs once rather
-- than once per window/space event. Re-arms after the next successful query.
local yabaiQueryFailureActive = false

local function failYabaiQuery(message)
  if not yabaiQueryFailureActive then
    hs.printf("yabaiQuery: %s", message)
    yabaiQueryFailureActive = true
  end
  return nil
end

--- Run a yabai query and return parsed JSON.
--- @param args string  e.g. "--windows --space"
--- @return table|nil   parsed result, or nil on failure
function M.yabaiQuery(args)
  local cmd = YABAI .. " -m query " .. args
  -- hs.execute() does not nil-check io.popen(); when the per-uid process table is
  -- exhausted (EAGAIN) it throws on a nil handle rather than returning a status,
  -- so the status check below is unreachable without pcall.
  local ran, output, status = pcall(hs.execute, cmd)
  if not ran then
    return failYabaiQuery("hs.execute failed: " .. tostring(output))
  end
  if not status then
    return failYabaiQuery("yabai exited non-zero")
  end
  local ok, result = pcall(hs.json.decode, output)
  if not ok then
    return failYabaiQuery("JSON decode failed: " .. tostring(result))
  end
  yabaiQueryFailureActive = false
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
