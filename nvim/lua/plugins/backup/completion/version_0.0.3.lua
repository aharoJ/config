
return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",        -- source for text in buffer
      "hrsh7th/cmp-path",          -- source for file system paths in commands
      "L3MON4D3/LuaSnip",          -- snippet engine
      "saadparwaiz1/cmp_luasnip",  -- for lua autocompletion
      "rafamadriz/friendly-snippets", -- useful snippets library
      "onsails/lspkind.nvim",      -- vs-code like pictograms
      "hrsh7th/cmp-nvim-lsp",      -- IDK WHY I DID THIS ONE ????????????? DEBUGGING ????????
    },
    config = function()
      local lspkind = require("lspkind")
      -------------------    TAB MAGIC    ------------------------
      local function check_backspace()
        local col = vim.fn.col(".") - 1
        return col == 0 or vim.fn.getline("."):sub(col, col):match("%s") ~= nil
      end
      ----------------                              ----------------
      local cmp = require("cmp") -- vscode like autocompletion
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = {
            border = "rounded", -- or "single", "double", "shadow"
            winhighlight = "NormalFloat:CompeDocumentation,FloatBorder:CompeDocumentationBorder",
            maxwidth = 80, -- Max width of the documentation window
            maxheight = 40, -- Max height of the documentation window
          },
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          -------------------    TAB FORWARD    ------------------------
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expandable() then
              luasnip.expand()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            elseif check_backspace() then
              fallback()
            else
              fallback()
            end
          end, { "i", "s" }),

          -------------------    TAB BACKWARDS    ------------------------
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
        ----------------                              ----------------
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" }, -- For Snippets
          { name = "buffer" }, -- text within current buffer
          { name = "path" }, -- file system paths
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol",    -- show only symbol annotations
            maxwidth = 50,      -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            ellipsis_char = "...", -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
            show_labelDetails = true, -- show labelDetails in menu. Disabled by default
          }),
        },
      })
    end,
  },
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
}
