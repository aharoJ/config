-- path: ~/.config/nvim-rebuild/lua/plugins/tools/tmux.lua
-- description: Neovim and tmux split navigation.
-- patched: Include the reviewed plugin specification in public exports.
-- date: 2026-10-03

return {
  "christoomey/vim-tmux-navigator",
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<CR>",  mode = { "n", "t" }, desc = "Navigate left (nvim/tmux)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<CR>",  mode = { "n", "t" }, desc = "Navigate down (nvim/tmux)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<CR>",    mode = { "n", "t" }, desc = "Navigate up (nvim/tmux)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<CR>", mode = { "n", "t" }, desc = "Navigate right (nvim/tmux)" },
  },
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
}
