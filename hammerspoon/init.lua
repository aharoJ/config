-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  init.lua — Hammerspoon Entry Point                                        ║
-- ║  path: ~/.config/hammerspoon/init.lua                                      ║
-- ║  description: loads modules, logs startup                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Add our config directory to the Lua package path
package.path = os.getenv("HOME") .. "/.config/hammerspoon/?.lua;" .. package.path

-- Enable IPC so `hs` CLI commands work (e.g. `hs -c "hs.reload()"`)
require("hs.ipc")

-- Load modules
local reload          = require("modules.reload")
local stackIndicators = require("modules.stack-indicators")
local utils           = require("modules.utils")

-- Initialize
reload.init()
stackIndicators.init()

-- Startup notification
hs.alert.show("Hammerspoon loaded", 1.5)
print(string.format("[%s] Hammerspoon config loaded", os.date("%H:%M:%S")))
