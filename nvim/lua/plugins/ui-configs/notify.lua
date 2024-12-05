vim.notify = require("notify")
require("notify").setup({
  background_colour = "#000000", -- transparent
  fps = 30,
  icons = {
    DEBUG = "",
    ERROR = "",
    INFO = "",
    TRACE = "✎",
    WARN = "",
  },
  level = 2,
  minimum_width = 30,
	maximum_width = 30,
  height= 20;
  width= 20;
  render = "compact",          -- default | minimal | simple | compact | wrapped-compact
  stages = "fade_in_slide_out", -- fade_in_slide_out | fade | slide | static
  time_formats = { -- I removed the time with render:compact 
    notification = "%T",
    notification_history = "%FT%T",
  },
  timeout = 300,
  top_down = true,
})

