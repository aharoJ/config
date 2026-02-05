-- plugins/core/transparent.lua
return {
  "xiyaowong/transparent.nvim",
  lazy = false,
  priority = 999, -- load right after colorscheme
  opts = {
    extra_groups = {
      -- Telescope
      "TelescopeNormal", "TelescopeBorder", "TelescopePromptNormal",
      -- Neo-tree
      "NeoTreeNormal", "NeoTreeNormalNC",
      -- Floats
      "NormalFloat", "FloatBorder",
      -- Notify
      "NotifyBackground",
      -- Lazy/Mason
      "LazyNormal", "MasonNormal",
    },
    exclude_groups = {}, -- groups you DON'T want transparent
  },
  config = function(_, opts)
    require("transparent").setup(opts)
    -- Clear plugin prefixes for full transparency
    require("transparent").clear_prefix("NeoTree")
    require("transparent").clear_prefix("Telescope")
    -- require("transparent").clear_prefix("lualine") -- optional, can look weird

    -- START WITH TRANSPARENCY OFF
    vim.cmd("TransparentDisable")

    -- MAPPINGS
    vim.keymap.set("n", "<leader>tt", "<cmd>TransparentToggle<cr>", { desc = "[t] transparent" })
  end,
}
