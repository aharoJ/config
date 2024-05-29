
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",
    "folke/neodev.nvim",
    "rcarriga/cmp-dap", -- Experimental
  },
  config = function()
    require("dapui").setup()
    
    -- Setup widgets just once
    local widgets = require("dap.ui.widgets")
    require("cmp").setup({
      enabled = function()
        return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt" or require("cmp_dap").is_dap_buffer()
      end,
    })
    
    require("cmp").setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
      sources = {
        { name = "dap" },
      },
    })
    
    -- Keybindings for debugging
    vim.keymap.set("n", "<Leader>dt", ":DapToggleBreakpoint<CR>")
    vim.keymap.set("n", "<Leader>dc", ":DapContinue<CR>")
    vim.keymap.set("n", "<Leader>dx", ":DapTerminate<CR>")
    vim.keymap.set("n", "<Leader>do", ":DapStepOver<CR>")
    vim.keymap.set("n", "<Leader>di", ":DapStepInto<CR>")
    vim.keymap.set("n", "<Leader>dO", ":DapStepOut<CR>") -- Fixed typo here

    -- Widgets keybindings
    vim.keymap.set({ "n", "v" }, "<Leader>Dh", widgets.hover)
    vim.keymap.set({ "n", "v" }, "<Leader>Dp", function()
      widgets.preview()
    end)
    vim.keymap.set("n", "<Leader>Df", function()
      widgets.centered_float(widgets.frames)
    end)
    vim.keymap.set("n", "<Leader>Ds", function()
      widgets.centered_float(widgets.scopes)
    end)
    
    -- neodev setup
    require("neodev").setup({
      library = { plugins = { "nvim-dap-ui" }, types = true },
    })
  end,
}
