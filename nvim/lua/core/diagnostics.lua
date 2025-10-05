-- path: nvim/lua/core/diagnostics.lua

if not vim.diagnostic then
	return
end

local sev = vim.diagnostic.severity

-- ── Sign icons (change these to taste) ────────────────────────────────────────
-- NOTE: We set sign text via `vim.diagnostic.config({ signs = { text = { ... }}})`
--       so we don't need to call :sign_define manually.
local SIGN_TEXT = {
	[sev.ERROR] = "", -- nf-fa-times_circle / codicons: x-circle
	[sev.WARN] = "", -- nf-fa-warning
	[sev.INFO] = "", -- nf-fa-info_circle
	[sev.HINT] = "", -- nf-fa-lightbulb_o
}

-- ── Core defaults (quiet by default; fast and readable) ──────────────────────
vim.diagnostic.config({
	-- Visual channels
	virtual_text = false, -- off by default; toggle when you want inline text
	virtual_lines = false, -- off by default; toggle big multiline messages
	underline = true, -- subtle underline keeps context without noise
	signs = {
		priority = 10,
		text = SIGN_TEXT,
		-- You can also light up the number column or line background per severity:
		-- numhl  = { [sev.ERROR] = "DiagnosticSignError", [sev.WARN] = "DiagnosticSignWarn" },
		-- linehl = { [sev.ERROR] = "ErrorMsg" },
	},

	-- Behavior
	update_in_insert = true, -- false | true
	severity_sort = true, -- false | true

	-- Floating window defaults (used by vim.diagnostic.open_float())
	float = {
		border = "rounded",
		header = "", -- clean header; set to "Diagnostics" if you want a title
		source = "if_many", -- show source name only when multiple
		focusable = false, -- mouse/keyboard won’t move focus into the float
		severity_sort = true,
		-- scope       = "line",   -- default is "line"; could be "cursor" if you prefer
		-- prefix/suffix/format can be set for fancy formatting if desired
	},

	-- Defaults for vim.diagnostic.jump() (used by ]d/[d when configured to float)
	jump = {
		wrap = true,
		float = { border = "rounded", source = "if_many", focusable = false },
		-- severity = { min = sev.HINT }, -- uncomment to limit default jump visibility
	},
})
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

-- ── Helpful keymaps (non-invasive; keep Neovim’s built-ins intact) ───────────
-- ]d / [d  → next/prev diagnostic
-- ]D / [D  → last/first diagnostic in buffer
-- gl → peek diagnostics at cursor (rounded float, shows source if many).
-- gK → toggle virtual_lines (big block messages).
-- gH → toggle virtual_text (inline end-of-line).
-- :DiagToggle → on/off globally.
-- :DiagMin WARN → only WARN/ERROR get signs/underline/float (try INFO, HINT, RESET).

-- Toggle virtual LINES: big multiline messages under code
vim.keymap.set("n", "gK", function()
	local cfg = vim.diagnostic.config()
	local new = not cfg.virtual_lines
	-- when turning on virtual_lines, keep virtual_text off to avoid double noise
	vim.diagnostic.config({ virtual_lines = new, virtual_text = false })
	vim.notify("diagnostic virtual_lines: " .. (new and "ON" or "OFF"))
end, { desc = "Toggle diagnostic virtual_lines" })

-- Toggle virtual TEXT inline (single-line snippets at EOL)
vim.keymap.set("n", "gH", function()
	local cfg = vim.diagnostic.config()
	local vt = cfg.virtual_text
	local new = not vt
	-- when turning on virtual_text, keep virtual_lines off to avoid clutter
	vim.diagnostic.config({ virtual_text = new, virtual_lines = false })
	vim.notify("diagnostic virtual_text: " .. (new and "ON" or "OFF"))
end, { desc = "Toggle diagnostic virtual_text" })

-- Quick peek at diagnostics at cursor (uses our float defaults)
vim.keymap.set("n", "gl", function()
	vim.diagnostic.open_float({ scope = "cursor" })
end, { desc = "Show diagnostic float at cursor" })
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

-- ── Convenience user commands ────────────────────────────────────────────────
-- :DiagToggle → enable/disable diagnostics globally
vim.api.nvim_create_user_command("DiagToggle", function()
	if vim.diagnostic.is_enabled() then
		vim.diagnostic.disable() -- global OFF
		vim.notify("diagnostics: OFF (global)")
	else
		vim.diagnostic.enable() -- global ON
		vim.notify("diagnostics: ON (global)")
	end
end, { desc = "Toggle diagnostics globally" })

-- 2) Map <leader>td to that toggle
vim.keymap.set("n", "<leader>td", function()
	if vim.diagnostic.is_enabled() then
		vim.diagnostic.disable()
		vim.notify("diagnostics: OFF (global)")
	else
		vim.diagnostic.enable()
		vim.notify("diagnostics: ON (global)")
	end
end, { desc = "Toggle diagnostics (global)" })

-- :DiagMin {ERROR|WARN|INFO|HINT|RESET}
-- Quickly set a minimum severity filter for underline/signs/float (keeps VT/VL choice)
vim.api.nvim_create_user_command("DiagMin", function(opts)
	local arg = (opts.args or ""):upper()
	local map = { ERROR = sev.ERROR, WARN = sev.WARN, INFO = sev.INFO, HINT = sev.HINT }
	if arg == "RESET" or arg == "" then
		vim.diagnostic.config({
			underline = true,
			signs = { priority = 10, text = SIGN_TEXT, severity = nil },
			float = vim.tbl_extend("force", vim.diagnostic.config().float or {}, { severity = nil }),
		})
		vim.notify("diagnostic min severity: RESET")
		return
	end
	local level = map[arg]
	if not level then
		vim.notify("DiagMin: expected ERROR|WARN|INFO|HINT|RESET", vim.log.levels.WARN)
		return
	end
	vim.diagnostic.config({
		underline = { severity = { min = level } },
		signs = { priority = 10, text = SIGN_TEXT, severity = { min = level } },
		float = vim.tbl_extend("force", vim.diagnostic.config().float or {}, { severity = { min = level } }),
	})
	vim.notify(("diagnostic min severity: %s"):format(arg))
end, {
	nargs = "?",
	complete = function()
		return { "ERROR", "WARN", "INFO", "HINT", "RESET" }
	end,
})
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- vim.diagnostic.config({
-- 	virtual_text = false,
-- 	virtual_lines = false,
-- 	signs = false,
--     underline=false,
-- })
