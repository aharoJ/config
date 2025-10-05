-- path: vim/lua/plugins/comment-code.lua


---@diagnostic disable: missing-fields
return {
  "numToStr/Comment.nvim",
  event = { "BufReadPre", "BufNewFile" },

  -- Ensure correct commentstring per node (JSX/TSX/Vue/Svelte/embedded langs)
  dependencies = {
    { "JoosepAlviste/nvim-ts-context-commentstring", lazy = true },
  },

  config = function()
    -- Safe-prehook: if ts-context-commentstring isn't available, don't error.
    local ok_tscc, tscc = pcall(require, "ts_context_commentstring.integrations.comment_nvim")

    require("Comment").setup({
      padding = true,          -- add a space between comment and code
      sticky  = true,          -- keep cursor position stable
      mappings = false,        -- we define our own (see below)
      -- ignore = "^$",        -- uncomment if you want to skip empty lines
      pre_hook = ok_tscc and tscc.create_pre_hook() or nil,
    })

    -- Keymaps (built on official <Plug> mappings for stability + dot-repeat)
    -- NORMAL: <leader>/ toggles current line; supports counts (e.g., 5<leader>/)
    vim.keymap.set("n", "<leader>/", function()
      return (vim.v.count == 0)
          and "<Plug>(comment_toggle_linewise_current)"
          or  "<Plug>(comment_toggle_linewise_count)"
    end, { expr = true, desc = "Toggle comment" })

    -- VISUAL: <leader>/ toggles the selection
    vim.keymap.set("x", "<leader>/", "<Plug>(comment_toggle_linewise_visual)",
      { desc = "Toggle comment (visual)" })
  end,
}

