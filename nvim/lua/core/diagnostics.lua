-- path: nvim/lua/core/diagnostics.lua

if not vim.diagnostic then
	return
end

-- ── Sign icons (change these to taste) ────────────────────────────────────────
local SIGN_TEXT = {
    [vim.diagnostic.severity.ERROR] = "",
    [vim.diagnostic.severity.WARN] = "",
    [vim.diagnostic.severity.INFO] = "",
    [vim.diagnostic.severity.HINT] = "",
}
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

-- ── Core defaults ──────────────────────
vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = false,
	underline = true,
	signs = {
		priority = 10,
		text = SIGN_TEXT,
	},
	update_in_insert = true,
	severity_sort = false,
	float = {
		border = "rounded",
		header = "",
		source = "if_many",
		focusable = false,
		severity_sort = false,
    },
    jump = {}, -- not sure what this does?
	-- jump = { wrap = true, float = { border = "rounded", source = "if_many", focusable = false }, }
})
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


-- ──────────────────────────────────────────────────────────────
-- MY BIDS
-- ──────────────────────────────────────────────────────────────
vim.keymap.set("n", "<leader>zl", function() vim.diagnostic.setloclist({ open = true, title = "Buffer Diagnostics" }) end, { desc = "[diag] → loclist" })
vim.keymap.set("n", "<leader>zL", function() vim.diagnostic.setqflist({ open = true, title = "Project Diagnostics" }) end, { desc = "[diag] → quickfix" })
vim.keymap.set("n", "<leader>co", vim.diagnostic.open_float, { desc = "[diag] → open float" })
vim.keymap.set("n", "<leader>td", function() if vim.diagnostic.is_enabled() then vim.diagnostic.enable(false, nil) vim.notify("[diag] → OFF") else vim.diagnostic.enable(true, nil) vim.notify("[diag] → ON") end end, { desc = "[diag] → ON | OFF" })
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     ...........       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
