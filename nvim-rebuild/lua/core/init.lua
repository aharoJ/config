-- path: nvim/lua/core/init.lua
-- Description: Bootstrap sequence. Leader key MUST be set before anything else.
--              This is the ONLY file that requires other core/ modules.
-- CHANGELOG: 2026-02-03 | Created bootstrap sequence | ROLLBACK: N/A (foundation)

-- ── 1. Leader Key ───────────────────────────────────────────
-- MUST be set before ANY plugin or keymap loads.
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- ── 2. Core Modules (deterministic order) ───────────────────
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.filetypes")

-- ── 3. Plugin Manager ───────────────────────────────────────
-- Loads AFTER core is fully initialized so plugins see correct settings.
require("config.lazy")
