return {
  "numToStr/Comment.nvim",
  dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
  config = function()
    -- require("ts_context_commentstring").setup()
    require("ts_context_commentstring").setup({
      enable_autocmd = true,
    })
    require("Comment").setup({
      padding = true,
      sticky = true,
      ignore = nil,

      toggler = {
        line = "gcc",
        block = "gbc",
      },

      opleader = {
        line = "gc",
        block = "gb",
      },

      extra = {
        above = "gcO",
        below = "gco",
        eol = "gcA",
      },
      mappings = {
        basic = true,
        extra = true,
      },
      pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
    })

    -- Instead of `gcc` we do <space>/
    -- Normal mode mapping for <Space>/
    vim.api.nvim_set_keymap("n", "<Leader>/", "<Plug>(comment_toggle_linewise_current)", { silent = true })
    vim.api.nvim_set_keymap("x", "<Leader>/", "<Plug>(comment_toggle_linewise_visual)", { silent = true })
  end,
}
