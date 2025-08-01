return {
  { -- tailwindcss vscode colo
    "brenoprata10/nvim-highlight-colors",
    config = function()
      vim.opt.termguicolors = true
      require("nvim-highlight-colors").setup({
        -- choose 'background' | 'foreground' | 'virtual'
        render = "virtual",
        virtual_symbol = "■",
        virtual_symbol_position = "inline", -- VS Code–style
        -- enable Tailwind class parsing:
        enable_tailwind = true,
        -- fine‑tune which formats to highlight:
        enable_hex = true,
        enable_rgb = true,
        enable_hsl = true,
        enable_var_usage = true,
        enable_named_colors = true,
      })
    end,
  },
  { -- hex vscode colo
    "norcalli/nvim-colorizer.lua",
    config = function()
      vim.opt.termguicolors = true
      require("colorizer").setup(
        { "*" },      -- or list specific filetypes: { "css", "html", "javascript", "typescript" }
        {
          RGB = true, -- #RGB
          RRGGBB = true, -- #RRGGBB
          RRGGBBAA = true, -- #RRGGBBAA
          names = true, -- "Blue", "Lime", etc.
          css = true, -- enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
          css_fn = true, -- enable `rgb()`/`hsl()` functions
        }
      )
    end,
  },
}
