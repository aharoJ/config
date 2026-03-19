-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  stack-indicators.lua — Visual Indicators for Yabai Window Stacks          ║
-- ║  path: ~/.config/hammerspoon/modules/stack-indicators.lua                  ║
-- ║  description: draws small pills on stacked window edges showing position   ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local utils = require("modules.utils")

local M = {}

-- ── Appearance ────────────────────────────────────────────────────────────────

local function getTheme()
  local dark = utils.isDarkMode()
  return {
    activeColor     = dark and { red = 0.4, green = 0.9, blue = 0.85, alpha = 1.0 }
                            or  { red = 0.2, green = 0.5, blue = 0.9,  alpha = 1.0 },
    inactiveColor   = dark and { red = 0.4, green = 0.9, blue = 0.85, alpha = 0.25 }
                            or  { red = 0.2, green = 0.5, blue = 0.9,  alpha = 0.20 },
    activeIconAlpha   = 1.0,
    inactiveIconAlpha = 0.4,
    pillSize      = 30,
    pillRadius    = 8,
    pillGap       = 6,
    iconPadding   = 4,
    edgeOffset    = 8,
  }
end

-- ── Icon Cache ──────────────────────────────────────────────────────────────

local iconCache = {}

local function getAppIcon(pid)
  local app = hs.application.get(pid)
  if not app then return nil end
  local bid = app:bundleID()
  if not bid then return nil end
  if iconCache[bid] then return iconCache[bid] end
  local icon = hs.image.imageFromAppBundle(bid)
  if icon then
    iconCache[bid] = icon
  end
  return icon
end

-- ── State ─────────────────────────────────────────────────────────────────────

local canvases = {}       -- all active canvas objects
local wfilter  = nil      -- hs.window.filter
local updateFn = nil      -- debounced update function

-- ── Core Logic ────────────────────────────────────────────────────────────────

--- Destroy all existing indicator canvases.
local function cleanup()
  for _, c in ipairs(canvases) do
    c:delete()
  end
  canvases = {}
  iconCache = {}
end

--- Query yabai for stacked windows on the current space.
--- Yabai assigns consecutive stack-index values (1, 2, 3...) to windows in the
--- same stack. All stacked windows on a space belong to one stack.
--- @return table[]|nil  sorted list of stacked windows, or nil
local function getStacks()
  local windows = utils.yabaiQuery("--windows --space")
  if not windows then
    return nil
  end

  -- Collect only stacked windows (stack-index > 0)
  local stacked = {}
  for _, w in ipairs(windows) do
    if w["is-visible"] and w["stack-index"] > 0 then
      table.insert(stacked, w)
    end
  end

  if #stacked < 2 then
    return nil
  end

  -- Sort by stack-index
  table.sort(stacked, function(a, b)
    return a["stack-index"] < b["stack-index"]
  end)

  return stacked
end

--- Determine which side of the screen a window is on.
--- @param frame table  { x, y, w, h }
--- @return string  "left" or "right"
local function getIndicatorSide(frame)
  local screen = hs.screen.mainScreen():frame()
  local windowCenter = frame.x + (frame.w / 2)
  local screenCenter = screen.x + (screen.w / 2)
  return windowCenter <= screenCenter and "left" or "right"
end

--- Draw indicators for the current space's stack.
local function draw()
  cleanup()

  local stack = getStacks()
  if not stack then
    return
  end

  local theme = getTheme()

  -- Use the focused (or first) window's frame as reference
  local ref = stack[1].frame
  local side = getIndicatorSide(ref)

  local sz = theme.pillSize

  -- Vertical: top-aligned, flush with window top edge
  local startY = ref.y + theme.edgeOffset

  -- Horizontal: in the yabai padding gap, outside the window edge
  local x = ref.x - sz - theme.edgeOffset

  -- Find the focused window in this stack
  local focusedIndex = nil
  for i, w in ipairs(stack) do
    if w["has-focus"] then
      focusedIndex = i
      break
    end
  end

  -- Draw each pill with app icon
  for i, w in ipairs(stack) do
    local y = startY + ((i - 1) * (sz + theme.pillGap))
    local isFocused = (i == focusedIndex)
    local color = isFocused and theme.activeColor or theme.inactiveColor
    local iconAlpha = isFocused and theme.activeIconAlpha or theme.inactiveIconAlpha

    local c = hs.canvas.new({ x = x, y = y, w = sz, h = sz })
    c:level(hs.canvas.windowLevels.cursor)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

    -- Pill background
    c[1] = {
      type             = "rectangle",
      fillColor        = color,
      strokeColor      = { alpha = 0 },
      roundedRectRadii = { xRadius = theme.pillRadius, yRadius = theme.pillRadius },
    }

    -- App icon
    local icon = getAppIcon(w.pid)
    if icon then
      local pad = theme.iconPadding
      local iconSize = sz - (pad * 2)
      c[2] = {
        type       = "image",
        image      = icon,
        imageAlpha = iconAlpha,
        frame      = { x = pad, y = pad, w = iconSize, h = iconSize },
      }
    end

    -- Click to focus
    c:clickActivating(false)
    c:mouseCallback(function(_, _, id, event)
      if event == "mouseUp" then
        local winObj = hs.window.get(w.id)
        if winObj then
          winObj:focus()
        end
      end
    end)
    c:canvasMouseEvents(true, false, false, false)

    c:show()
    table.insert(canvases, c)
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.init()
  -- Debounce redraws to avoid hammering yabai during rapid window changes
  updateFn = utils.debounce(draw, 0.1)

  -- Window filter: subscribe to relevant events
  wfilter = hs.window.filter.default
  wfilter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowMoved,
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnfocused,
    hs.window.filter.windowMinimized,
    hs.window.filter.windowUnminimized,
    hs.window.filter.windowHidden,
    hs.window.filter.windowUnhidden,
  }, function()
    updateFn()
  end)

  -- Also watch for space changes
  M.spaceWatcher = hs.spaces.watcher.new(function()
    updateFn()
  end)
  M.spaceWatcher:start()

  -- Initial draw
  draw()
end

function M.cleanup()
  if wfilter then
    wfilter:unsubscribeAll()
  end
  if M.spaceWatcher then
    M.spaceWatcher:stop()
  end
  cleanup()
end

return M
