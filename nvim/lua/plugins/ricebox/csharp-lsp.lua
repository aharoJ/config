return {
  {
    "Hoffs/omnisharp-extended-lsp.nvim",
    config = function()
      -- Add your keymaps here
      vim.keymap.set(
        "n",
        "gd",
        "<cmd>lua require('omnisharp_extended').lsp_definition()<CR>",
        { desc = "OmniSharp Definition" }
      )
      vim.keymap.set(
        "n",
        "gr",
        "<cmd>lua require('omnisharp_extended').lsp_references()<CR>",
        { desc = "OmniSharp References" }
      )
      vim.keymap.set(
        "n",
        "gi",
        "<cmd>lua require('omnisharp_extended').lsp_implementation()<CR>",
        { desc = "OmniSharp Implementation" }
      )
    end,
  },
}
