-- path: nvim/lua/plugins/autocomplete.lua

return {
  -----------------------------------------------------------------------------
  -- CORE COMPLETION ENGINE ---------------------------------------------------
  -----------------------------------------------------------------------------
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "onsails/lspkind-nvim",
      "windwp/nvim-autopairs",
    },
    config = function()
      ------------------------------------------------------------------------
      -- LuaSnip -------------------------------------------------------------
      ------------------------------------------------------------------------
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load() -- Load VS Code snippets

      ------------------------------------------------------------------------
      -- nvim-autopairs integration ------------------------------------------
      ------------------------------------------------------------------------
      local cmp = require("cmp")
      require("nvim-autopairs").setup({})
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

      ------------------------------------------------------------------------
      -- lspkind (icons) -----------------------------------------------------
      ------------------------------------------------------------------------
      local lspkind = require("lspkind")
      local kind_icons = {
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

      ------------------------------------------------------------------------
      -- Custom border for completion and documentation windows --------------
      ------------------------------------------------------------------------
      local border = {
        { "╭", "FloatBorder" },
        { "─", "FloatBorder" },
        { "╮", "FloatBorder" },
        { "│", "FloatBorder" },
        { "╯", "FloatBorder" },
        { "─", "FloatBorder" },
        { "╰", "FloatBorder" },
        { "│", "FloatBorder" },
      }

      ------------------------------------------------------------------------
      -- cmp.setup() ---------------------------------------------------------
      ------------------------------------------------------------------------
      cmp.setup({
        completion = {
          completeopt = "menu,menuone,noinsert,noselect", -- Keep noselect
          autocomplete = false,                      -- Disable auto-popup on typing
        },
        -- Disable ghost text completely
        experimental = { ghost_text = true },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered({
            border = border,
            winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
          }),
          documentation = cmp.config.window.bordered({
            border = border,
            winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
          }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(), -- Manual trigger
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-c>"] = cmp.mapping.close(),

          -- Only confirm when explicitly selected
          ["<CR>"] = cmp.mapping.confirm({
            select = false, -- Require explicit selection
            behavior = cmp.ConfirmBehavior.Replace,
          }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
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
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "…",
            symbol_map = kind_icons,
          }),
        },
        sources = {
          { name = "nvim_lsp", dup = 0 },
          { name = "luasnip",  dup = 0 },
          { name = "path",     dup = 0 },
          { name = "buffer",   dup = 0 },
        },
      })

      ------------------------------------------------------------------------
      -- Cmd-line completion -------------------------------------------------
      ------------------------------------------------------------------------
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },

  -----------------------------------------------------------------------------
  -- LSPCONFIG WRAPPER WITH PER-SERVER CAPABILITIES --------------------------
  -----------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local cmp_cap = require("cmp_nvim_lsp").default_capabilities()
      local common_on_attach = function(_, _) end

      ----------------------------------------------------------------------
      -- Default servers ----------------------------------------------------
      ----------------------------------------------------------------------
      local lsp = require("lspconfig")
      local simple_servers = {
        "pyright",
        "tsserver",
        "rust_analyzer",
        "gopls",
        "html",
        "cssls",
        "lua_ls",
      }
      for _, s in ipairs(simple_servers) do
        lsp[s].setup({
          capabilities = cmp_cap,
          on_attach = common_on_attach,
        })
      end

      ----------------------------------------------------------------------
      -- JDTLS (Java) – snippets disabled -----------------------------------
      ----------------------------------------------------------------------
      local jdt_cap = vim.deepcopy(cmp_cap)
      jdt_cap.textDocument.completion.completionItem.snippetSupport = false
      lsp.jdtls.setup({
        capabilities = jdt_cap,
        on_attach = common_on_attach,
      })
    end,
  },
}
