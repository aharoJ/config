return {
  "nvimdev/dashboard-nvim",
  enabled = false,
  config = function()
    local theme = require("plugins.dashboard-theme.landing")
    -- local theme = require('plugins.dashboard-theme.doom')
    -- local theme = require('plugins.dashboard-theme.minimal')
    -- local theme = require('plugins.dashboard-theme.hyper')
    require("dashboard").setup(theme)
  end,
}
