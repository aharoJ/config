-- path: nvim/lua/plugins/core/telescope.lua
-- Description: Fuzzy finder. Lazy-loaded via keys = {} and cmd = {}.
--              All keymaps live HERE, not in core/keymaps.lua (Principle 8).
-- CHANGELOG: 2026-02-03 | Moved from plugins/ to plugins/core/ | ROLLBACK: Move back to plugins/telescope.lua

return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Find buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
    { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics" },
    { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Fuzzy search in buffer" },
  },
  opts = {
    defaults = {
      file_ignore_patterns = {
        "node_modules",
        ".git/",
        "target/",
        "build/",
        ".class",
        "%.lock",
      },
      layout_config = {
        horizontal = { preview_width = 0.55 },
      },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    telescope.load_extension("fzf")
  end,
}
