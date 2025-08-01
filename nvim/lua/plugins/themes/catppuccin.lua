-- nvim/lua/plugins/themes/catppuccin.lua

return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      background = { light = "latte", dark = "mocha" },
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = false,
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

        mocha = function(mocha)
          -----------------------------------------------------------------
          -- palette inspired by Java section above
          -----------------------------------------------------------------
          local col = {
            indigo = "#6C7891",
            ltGreen = "#B0C8A9",
            dkYellow = "#B8AD9E",
            brnYel = "#D1C8B0",
            blueLt = "#82A8DD",
            green = "#7E9C8C",
            purple = "#7F88C5",
            pink = "#C57F9E",
            pinkLt = "#F2B8D2",
            bluLav = "#C2CBF2",
            rose = "#AA788D",
            bluSoft = "#A9BEDA",
          }

          return {
            -----------------------------------------------------------------
            -- JAVA (unchanged)
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
            ["@type.builtin.typescript"] = { fg = col.green },
            ["@keyword.return.typescript"] = { fg = col.purple },
            ["@keyword.operator.javascript"] = { fg = col.pink },
            ["@property.typescript"] = { fg = col.purple },
            ["@lsp.type.enum.typescript"] = { fg = col.brnYel },

            -----------------------------------------------------------------
            -- TSX / JSX
            -----------------------------------------------------------------
            ["@tag.tsx"] = { fg = col.dkYellow, style = { "bold" } },
            ["@tag.delimiter.tsx"] = { fg = col.indigo },
            ["@tag.attribute.tsx"] = { fg = col.green, style = { "italic" } },
            ["@tag.builtin.tsx"] = { fg = col.purple }, -- this
            ["@attribute.tsx"] = { fg = col.rose },
            ["@variable.tsx"] = { fg = col.bluLav },
            ["@variable.member.tsx"] = { fg = col.bluLav },
            ["@type.tsx"] = { fg = col.blueLt },
            ["@function.tsx"] = { fg = col.blueLt },
            ["@string.tsx"] = { fg = col.ltGreen }, -- THIS ONE
            ["@property.tsx"] = { fg = col.bluSoft },
            ["@_jsx_element.tsx"] = { fg = col.purple }, -- this
            ["@_jsx_attribute.tsx"] = { fg = col.green },
            ["@keyword.import.tsx"] = { fg = col.green },

            ["@lsp.type.function.typescriptreact"] = { fg = col.blueLt },
            ["@lsp.mod.declaration.typescriptreact"] = { fg = col.bluSoft },
            ["@lsp.mod.readonly.typescriptreact"] = { fg = col.bluSoft, style = { "italic" } },
            ["@lsp.typemod.function.declaration.typescriptreact"] = { fg = col.blueLt },
            ["@lsp.typemod.function.readonly.typescriptreact"] = { fg = col.green },

            -----------------------------------------------------------------
            -- HTML
            -----------------------------------------------------------------
            ["@tag.html"] = { fg = col.pinkLt, style = { "bold" } },
            ["@tag.delimiter.html"] = { fg = col.indigo },
            ["@tag.attribute.html"] = { fg = col.green, style = { "italic" } },
            ["@attribute.html"] = { fg = col.rose },
            ["@string.special.html"] = { fg = col.ltGreen },
            ["@punctuation.bracket.html"] = { fg = col.indigo },

            -----------------------------------------------------------------
            -- CSS
            -----------------------------------------------------------------
            ["@type.css"] = { fg = col.green },
            ["@type.builtin.css"] = { fg = col.indigo },
            ["@class.css"] = { fg = col.pink, style = { "italic" } },
            ["@property.css"] = { fg = col.rose },
            ["@number.css"] = { fg = col.brnYel },
            ["@function.css"] = { fg = col.blueLt },
            ["@function.builtin.css"] = { fg = col.blueLt },
            ["@keyword.css"] = { fg = col.purple, style = { "bold" } },
            ["@boolean.css"] = { fg = col.brnYel },
            ["@string.css"] = { fg = col.ltGreen },
            ["@constant.numeric"] = { fg = col.brnYel },
          }
        end,
      },

      custom_highlights = {},
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = { enabled = true, indentscope_color = "" },
      },
    })

    vim.cmd.colorscheme("catppuccin")
  end,
}
