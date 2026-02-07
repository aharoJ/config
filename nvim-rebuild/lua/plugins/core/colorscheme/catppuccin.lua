-- plugins/core/colorscheme/catppuccin.lua
-- Catppuccin — Pastel perfection, massive community support
-- 4 flavors: Latte (light), Frappé (medium), Macchiato (warm), Mocha (dark)
-- Best plugin integrations of any theme.
--
-- PALETTE REFERENCE (Mocha variant):
--   rosewater    #f5e0dc   (soft pink)
--   flamingo     #f2cdcd   (pink)
--   pink         #f5c2e7   (bright pink)
--   mauve        #cba6f7   (purple)
--   red          #f38ba8   (red - errors)
--   maroon       #eba0ac   (dark red)
--   peach        #fab387   (orange)
--   yellow       #f9e2af   (yellow - warnings)
--   green        #a6e3a1   (green - success)
--   teal         #94e2d5   (teal)
--   sky          #89dceb   (light blue)
--   sapphire     #74c7ec   (blue)
--   blue         #89b4fa   (bright blue)
--   lavender     #b4befe   (light purple)
--   text         #cdd6f4   (main text)
--   subtext1     #bac2de   (secondary text)
--   subtext0     #a6adc8   (tertiary text)
--   overlay2     #9399b2   (overlay)
--   overlay1     #7f849c   (overlay)
--   overlay0     #6c7086   (overlay)
--   surface2     #585b70   (elevated surface)
--   surface1     #45475a   (surface)
--   surface0     #313244   (base surface)
--   base         #1e1e2e   (main bg)
--   mantle       #181825   (darker bg)
--   crust        #11111b   (darkest bg)

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  enabled = false, -- 👈 flip to true to activate
  priority = 1000,
  opts = {
    flavour = "mocha", -- latte, frappe, macchiato, mocha
    background = { light = "latte", dark = "mocha" },
    transparent_background = false,
    show_end_of_buffer = false,
    term_colors = true,
    dim_inactive = { enabled = false, shade = "dark", percentage = 0.15 },
    no_italic = false,
    no_bold = false,
    no_underline = false,

    styles = {
      comments = { "italic" },
      conditionals = { "italic" },
      loops = {},
      functions = {},
      keywords = {},
      strings = {},
      variables = {},
      numbers = {},
      booleans = {},
      properties = {},
      types = {},
      operators = {},
    },

    color_overrides = {},

    highlight_overrides = {
      mocha = function(colors)
        -- Custom palette for fire syntax highlighting
        local col = {
          indigo    = "#6C7891",
          ltGreen   = "#B0C8A9",
          dkYellow  = "#B8AD9E",
          brnYel    = "#D1C8B0",
          blueLt    = "#82A8DD",
          green     = "#7E9C8C",
          purple    = "#7F88C5",
          pink      = "#C57F9E",
          pinkLt    = "#F2B8D2",
          bluLav    = "#C2CBF2",
          rose      = "#AA788D",
          bluSoft   = "#A9BEDA",
        }

        return {
          -----------------------------------------------------------------
          -- JAVA
          -----------------------------------------------------------------
          ["@keyword.import.java"] = { fg = col.indigo },
          ["@lsp.type.modifier.java"] = { fg = col.ltGreen },
          ["@lsp.typemod.class.public.java"] = { fg = col.brnYel },
          ["@lsp.typemod.method.public.java"] = { fg = col.blueLt },
          ["@lsp.type.parameter.java"] = { fg = col.rose },
          ["@type.builtin.java"] = { fg = col.green },
          ["@keyword.conditional.java"] = { fg = col.purple },
          ["@keyword.repeat.java"] = { fg = col.purple },
          ["@keyword.return.java"] = { fg = col.purple },
          ["@number.java"] = { fg = col.brnYel },
          ["@number.float.java"] = { fg = col.brnYel },
          ["@constant.builtin.java"] = { fg = col.brnYel },
          ["@string.java"] = { fg = col.ltGreen },
          ["@attribute.java"] = { fg = col.purple },
          ["@variable.java"] = { fg = col.bluLav },

          -----------------------------------------------------------------
          -- TYPESCRIPT / JAVASCRIPT
          -----------------------------------------------------------------
          ["@variable.typescript"] = { fg = col.bluLav },
          ["@variable.javascript"] = { fg = col.bluLav },
          ["@property.typescript"] = { fg = col.rose },
          ["@property.javascript"] = { fg = col.rose },
          ["@function.typescript"] = { fg = col.blueLt },
          ["@function.javascript"] = { fg = col.blueLt },
          ["@function.method.typescript"] = { fg = col.blueLt },
          ["@function.method.javascript"] = { fg = col.blueLt },
          ["@keyword.typescript"] = { fg = col.purple },
          ["@keyword.javascript"] = { fg = col.purple },
          ["@keyword.return.typescript"] = { fg = col.purple },
          ["@keyword.return.javascript"] = { fg = col.purple },
          ["@keyword.import.typescript"] = { fg = col.indigo },
          ["@keyword.import.javascript"] = { fg = col.indigo },
          ["@keyword.export.typescript"] = { fg = col.indigo },
          ["@keyword.export.javascript"] = { fg = col.indigo },
          ["@type.typescript"] = { fg = col.brnYel },
          ["@type.javascript"] = { fg = col.brnYel },
          ["@type.builtin.typescript"] = { fg = col.green },
          ["@type.builtin.javascript"] = { fg = col.green },
          ["@string.typescript"] = { fg = col.ltGreen },
          ["@string.javascript"] = { fg = col.ltGreen },
          ["@number.typescript"] = { fg = col.brnYel },
          ["@number.javascript"] = { fg = col.brnYel },
          ["@boolean.typescript"] = { fg = col.brnYel },
          ["@boolean.javascript"] = { fg = col.brnYel },
          ["@constant.typescript"] = { fg = col.brnYel },
          ["@constant.javascript"] = { fg = col.brnYel },

          -----------------------------------------------------------------
          -- TSX / JSX (React)
          -----------------------------------------------------------------
          ["@tag.tsx"] = { fg = col.pinkLt, bold = true },
          ["@tag.jsx"] = { fg = col.pinkLt, bold = true },
          ["@tag.delimiter.tsx"] = { fg = col.indigo },
          ["@tag.delimiter.jsx"] = { fg = col.indigo },
          ["@tag.attribute.tsx"] = { fg = col.green, italic = true },
          ["@tag.attribute.jsx"] = { fg = col.green, italic = true },

          -----------------------------------------------------------------
          -- HTML
          -----------------------------------------------------------------
          ["@tag.html"] = { fg = col.pinkLt, bold = true },
          ["@tag.delimiter.html"] = { fg = col.indigo },
          ["@tag.attribute.html"] = { fg = col.green, italic = true },
          ["@attribute.html"] = { fg = col.rose },
          ["@string.special.html"] = { fg = col.ltGreen },
          ["@punctuation.bracket.html"] = { fg = col.indigo },

          -----------------------------------------------------------------
          -- CSS
          -----------------------------------------------------------------
          ["@type.css"] = { fg = col.green },
          ["@type.builtin.css"] = { fg = col.indigo },
          ["@class.css"] = { fg = col.pink, italic = true },
          ["@property.css"] = { fg = col.rose },
          ["@number.css"] = { fg = col.brnYel },
          ["@function.css"] = { fg = col.blueLt },
          ["@function.builtin.css"] = { fg = col.blueLt },
          ["@keyword.css"] = { fg = col.purple, bold = true },
          ["@boolean.css"] = { fg = col.brnYel },
          ["@string.css"] = { fg = col.ltGreen },
          ["@constant.numeric"] = { fg = col.brnYel },

          -----------------------------------------------------------------
          -- LUA
          -----------------------------------------------------------------
          ["@variable.lua"] = { fg = col.bluLav },
          ["@function.lua"] = { fg = col.blueLt },
          ["@function.builtin.lua"] = { fg = col.blueLt },
          ["@keyword.lua"] = { fg = col.purple },
          ["@keyword.return.lua"] = { fg = col.purple },
          ["@keyword.function.lua"] = { fg = col.purple },
          ["@string.lua"] = { fg = col.ltGreen },
          ["@number.lua"] = { fg = col.brnYel },
          ["@boolean.lua"] = { fg = col.brnYel },
          ["@constant.builtin.lua"] = { fg = col.brnYel },
          ["@field.lua"] = { fg = col.rose },
          ["@property.lua"] = { fg = col.rose },
        }
      end,
    },

    custom_highlights = {},

    integrations = {
      cmp = true,
      gitsigns = true,
      nvimtree = true,
      neotree = true,
      treesitter = true,
      notify = true,
      telescope = { enabled = true },
      mason = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      mini = { enabled = true, indentscope_color = "" },
      indent_blankline = { enabled = true, colored_indent_levels = false },
      which_key = true,
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
