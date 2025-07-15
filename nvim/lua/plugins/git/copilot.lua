-- <C-[> breaks Nvim
return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      panel = {
        enabled = true,
        auto_refresh = true,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<C-P>", -- M dont work on MacOs
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      suggestion = {
        enabled = true,
        auto_trigger = false, -- so we have to manually trigger it
        debounce = 75,
        keymap = {
          accept = "<C-J>",
          accept_word = false,
          accept_line = false,
          next = "<C-]>",
          -- prev = "<M-[>", -- M dont work on MacOs
          dismiss = "<C-H>",
        },
      },
      filetypes = {
        yaml = true,
        markdown = true,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["."] = false,
      },
      copilot_node_command = "node", -- Node.js version must be > 18.x
      server_opts_overrides = {
        trace = "verbose",
        settings = {
          advanced = {
            listCount = 10,     -- #completions for panel
            inlineSuggestCount = 3, -- #completions for getCompletions
          },
        },
      },
    })

    vim.keymap.set("n","<leader>tp","<cmd>lua require('copilot.panel').open()<CR>",{ desc="[copilot] pannel" })
    vim.keymap.set("n","<leader>tc","<cmd>lua require('copilot.suggestion').toggle_auto_trigger()<CR>",{ desc="[copilot] on|off" })
  end
}
