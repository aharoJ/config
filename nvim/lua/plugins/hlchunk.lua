return {
  "shellRaining/hlchunk.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("hlchunk").setup({
      chunk = {
        enable = true, -- Ensure this is a table, not just a boolean
        priority = 15,
        style = {
          { fg = "#806d9c" },
          { fg = "#c21f30" },
        },
        use_treesitter = true,
        chars = {
          horizontal_line = "─",
          vertical_line = "│",
          left_top = "╭",
          left_bottom = "╰",
          right_arrow = ">",
        },
        textobject = "",
        max_file_size = 1024 * 1024,
        error_sign = true,
        duration = 200,
        delay = 300,
      },
      indent = {
        enable = false, -- You can set this to true if you want to enable the indent feature
      },
      line_num = {
        enable = false, -- Disable or configure if needed
      },
      blank = {
        enable = false, -- Disable or configure if needed
      },
    })
  end,
}
