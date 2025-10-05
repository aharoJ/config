-- path: nvim/init.lua
---@diagnostic disable: undefined-global

-- core stuff
require("core.globals")
require("core.clipboard")
require("core.options")
require("core.mute")
require("core.diagnostics")
require("core.keymaps")
require("core.paths")
require("core.files").setup()
require("core.tools-binaries")

-- lazy
require("config.lazy")
