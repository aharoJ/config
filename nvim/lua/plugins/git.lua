return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  dependencies = {
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    -- <C-[> breaks Nvim
    require("plugins.git.copilot")
    require("plugins.git.gitsings")
  end,
}
