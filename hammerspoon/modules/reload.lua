-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  reload.lua — Auto-reload & Manual Reload                                  ║
-- ║  path: ~/.config/hammerspoon/modules/reload.lua                            ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local M = {}

local configDir = os.getenv("HOME") .. "/.config/hammerspoon/"

--- Watch the config directory for changes and auto-reload.
function M.init()
  M.watcher = hs.pathwatcher.new(configDir, function(files)
    local dominated = false
    for _, file in ipairs(files) do
      if file:match("%.lua$") then
        dominated = true
        break
      end
    end
    if dominated then
      hs.reload()
    end
  end)
  M.watcher:start()

  -- No manual hotkey — pathwatcher handles reload on any .lua save.
  -- If you need a manual reload: hs.reload() from the Hammerspoon console,
  -- or `hs -c "hs.reload()"` from terminal/skhd.
end

return M
