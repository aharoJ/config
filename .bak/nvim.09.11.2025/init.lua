-- path: nvim/init.lua
---@diagnostic disable: undefined-global

-- core stuff
require("core.globals")
require("core.options")
require("core.mute")
require("core.diagnostics")
require("core.keymaps")

-- package manager
require("config.lazy")
