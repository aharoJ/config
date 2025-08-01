-- path: nvim/lua/plugins/autocomplete.lua

return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local cmp_enabled = true

      -- Toggle autocomplete with <leader>ta
      vim.keymap.set("n", "<leader>ta", function()
        cmp_enabled = not cmp_enabled
        if not cmp_enabled then
          cmp.close()
        end
        vim.notify("Autocomplete " .. (cmp_enabled and "ENABLED" or "DISABLED"))
      end, { desc = "Toggle autocomplete" })

      -- Load snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        enabled = function()
          return cmp_enabled
        end,
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            -- Kind icons
            local icons = {
              Text = "",
              Method = "󰆧",
              Function = "󰊕",
              Constructor = "",
              Field = "",
              Variable = "",
              Class = "",
              Interface = "",
              Module = "",
              Property = "",
              Unit = "",
              Value = "󰎠",
              Enum = "",
              Keyword = "",
              Snippet = "",
              Color = "",
              File = "",
              Reference = "",
              Folder = "",
              EnumMember = "",
              Constant = "󰏿",
              Struct = "",
              Event = "",
              Operator = "",
              TypeParameter = "",
            }
            vim_item.kind = string.format("%s %s", icons[vim_item.kind] or "", vim_item.kind)

            -- Source/module information
            local source_names = {
              nvim_lsp = "LSP",
              luasnip = "Snippet",
              path = "Path",
            }

            local source_name = source_names[entry.source.name] or entry.source.name
            local module_name = ""

            -- Try different sources for module information
            if entry.completion_item then
              -- 1. Try LSP 3.17 labelDetails.description
              if
                  entry.completion_item.labelDetails and entry.completion_item.labelDetails.description
              then
                module_name = entry.completion_item.labelDetails.description

                -- 2. Handle Python auto-import case
              elseif
                  entry.completion_item.detail == "auto-import"
                  and entry.completion_item.data
                  and entry.completion_item.data.import
              then
                module_name = entry.completion_item.data.import:match("[%w_]+$") or ""

                -- 3. Fallback to detail field
              elseif entry.completion_item.detail then
                module_name = entry.completion_item.detail
              end
            end

            -- Format menu text
            if module_name ~= "" then
              vim_item.menu = string.format("%s • %s", source_name, module_name)
            else
              vim_item.menu = source_name
            end

            return vim_item
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }),
      })
    end,
  },
  { -- auto paiting {} () " " ...
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" }, 
    config = function()
      local autopairs = require("nvim-autopairs")
      autopairs.setup({
        check_ts = true,
        fast_wrap = {}, -- <M-e> surrounds selection
      })

      -- cmp integration -------------------------------------------------------
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp") -- moved after require(...)
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
}
