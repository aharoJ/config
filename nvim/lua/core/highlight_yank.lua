-- ── Highlight on yank (neon blue flash) ────────────────────────────────
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text in bright neon blue",
  group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({
      higroup = "YankHighlight",
      timeout = 300, -- milliseconds the highlight stays visible
      on_visual = true,
    })
  end,
})

-- ── Custom neon blue color definition ──────────────────────────────────
vim.api.nvim_set_hl(0, "YankHighlight", {
  fg = "NONE",
  bg = "#00bfff", -- 💙 bright neon blue (change if you want a different tone)
  bold = true,
})
