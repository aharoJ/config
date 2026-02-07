-- path: nvim/lua/plugins/autocomplete/autocomplete.lua
return {
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "hrsh7th/cmp-nvim-lua",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            {
                "rafamadriz/friendly-snippets",
                config = function()
                    require("luasnip.loaders.from_vscode").lazy_load()
                end,
            },
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            -- Toggle autocomplete
            local cmp_enabled = true
            vim.keymap.set("n", "<leader>ta", function()
                cmp_enabled = not cmp_enabled
                vim.notify("Autocomplete " .. (cmp_enabled and "ENABLED" or "DISABLED"))
            end, { desc = "Toggle autocomplete" })

            ------------------------------------------------------------------------
            -- ICONS + SOURCE NAMES (precomputed for hot path)
            ------------------------------------------------------------------------
            local ICONS = {
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

            local SOURCE_NAMES = {
                nvim_lsp = "",
                luasnip  = "",
                path     = "",
                buffer   = "󰈚",
                nvim_lua = "",
            }

            local function lsp_module_name(entry)
                local ci = entry and entry.completion_item
                if not ci then return "" end
                local ld = ci.labelDetails
                if ld and ld.description and ld.description ~= "" then
                    return ld.description
                end
                if ci.detail == "auto-import" and ci.data and ci.data.import then
                    return (ci.data.import:match("[%w_]+$")) or ""
                end
                if ci.detail and ci.detail ~= "" then
                    return ci.detail
                end
                return ""
            end

            ------------------------------------------------------------------------
            -- HIGHLIGHTS (VS Code-style look)
            ------------------------------------------------------------------------
            vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", { strikethrough = true, fg = "#7c6f64" })
            vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { bold = true, fg = "#88c0d0" })
            vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { bold = true, fg = "#88c0d0" })
            vim.api.nvim_set_hl(0, "CmpItemMenu", { italic = true, fg = "#808080" })
            vim.api.nvim_set_hl(0, "CmpItemKind", { fg = "#C586C0" })
            vim.api.nvim_set_hl(0, "CmpBorder", { fg = "#404040" })
            vim.api.nvim_set_hl(0, "CmpSel", { bg = "#1c1e2b" })
            vim.api.nvim_set_hl(0, "CmpDoc", { bg = "None" })
            vim.api.nvim_set_hl(0, "CmpItemKindClass", { fg = "#EE9D28" })
            vim.api.nvim_set_hl(0, "CmpItemKindInterface", { fg = "#75BEFF" })
            vim.api.nvim_set_hl(0, "CmpItemKindFunction", { fg = "#C586C0" })
            vim.api.nvim_set_hl(0, "CmpItemKindMethod", { fg = "#C586C0" })
            vim.api.nvim_set_hl(0, "CmpItemKindVariable", { fg = "#75BEFF" })
            vim.api.nvim_set_hl(0, "CmpItemKindField", { fg = "#75BEFF" })
            vim.api.nvim_set_hl(0, "CmpItemKindProperty", { fg = "#75BEFF" })
            vim.api.nvim_set_hl(0, "CmpItemKindConstant", { fg = "#4FC1FF" })
            vim.api.nvim_set_hl(0, "CmpItemKindEnum", { fg = "#EE9D28" })
            vim.api.nvim_set_hl(0, "CmpItemKindEnumMember", { fg = "#4FC1FF" })
            vim.api.nvim_set_hl(0, "CmpItemKindStruct", { fg = "#EE9D28" })
            vim.api.nvim_set_hl(0, "CmpItemKindKeyword", { fg = "#569CD6" })
            vim.api.nvim_set_hl(0, "CmpItemKindSnippet", { fg = "#4EC9B0" })
            vim.api.nvim_set_hl(0, "CmpItemKindText", { fg = "#CCCCCC" })
            vim.api.nvim_set_hl(0, "CmpItemKindModule", { fg = "#EE9D28" })
            vim.api.nvim_set_hl(0, "CmpItemKindFile", { fg = "#CCCCCC" })

            ------------------------------------------------------------------------
            -- CORE SETUP
            ------------------------------------------------------------------------
            cmp.setup({
                preselect = cmp.PreselectMode.Item,
                enabled = function()
                    local context = require("cmp.config.context")
                    if context.in_treesitter_capture("comment") or context.in_syntax_group("Comment") then
                        return false
                    end
                    local bt = vim.api.nvim_get_option_value("buftype", { buf = 0 })
                    return cmp_enabled and bt ~= "prompt"
                end,
                completion = { completeopt = "menu,menuone,noinsert" },
                snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
                window = {
                    completion = {
                        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
                        scrollbar = false,
                        col_offset = -3,
                        side_padding = 0,
                        winhighlight = "Normal:Normal,FloatBorder:CmpBorder,CursorLine:CmpSel,Search:None",
                    },
                    documentation = false,
                },
                formatting = {
                    fields = { "kind", "abbr", "menu" },
                    format = function(entry, vim_item)
                        local src = entry.source.name
                        if src == "buffer" or src == "path" then
                            local icon = ICONS[vim_item.kind]
                            if icon then vim_item.kind = icon .. " " .. vim_item.kind end
                            vim_item.menu = SOURCE_NAMES[src] or src
                            if #vim_item.abbr > 30 then vim_item.abbr = vim_item.abbr:sub(1, 27) .. "…" end
                            return vim_item
                        end
                        local icon = ICONS[vim_item.kind]
                        if icon then vim_item.kind = icon .. " " .. vim_item.kind end
                        local module_name = (src == "nvim_lsp") and lsp_module_name(entry) or ""
                        local src_name = SOURCE_NAMES[src] or src
                        if module_name ~= "" then
                            if #module_name > 40 then
                                local start = module_name:sub(1, 15)
                                local last_two = module_name:match("([^%.]+%.[^%.]+)$") or module_name:sub(-20)
                                module_name = start .. "..." .. last_two
                            end
                            vim_item.menu = src_name .. module_name
                        else
                            vim_item.menu = src_name
                        end
                        if #vim_item.abbr > 30 then vim_item.abbr = vim_item.abbr:sub(1, 27) .. "…" end
                        return vim_item
                    end,
                },
                sorting = {
                    priority_weight = 1.0,
                    comparators = {
                        cmp.config.compare.offset,
                        cmp.config.compare.exact,
                        cmp.config.compare.score,
                        cmp.config.compare.kind,
                        cmp.config.compare.length,
                        cmp.config.compare.order,
                    },
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"] = cmp.mapping.abort(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true, behavior = cmp.ConfirmBehavior.Replace }),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                        elseif luasnip.expand_or_locally_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    {
                        name = "nvim_lsp",
                        priority = 1000,
                        entry_filter = function(entry)
                            return entry:get_kind() ~= 1 -- filter out plain Text items
                        end
                    },
                    { name = "luasnip",  priority = 900 },
                    { name = "nvim_lua", priority = 800 },
                    {
                        name = "buffer",
                        priority = 500,
                        keyword_length = 3,
                        get_bufnrs = function()
                            local bufs = {}
                            for _, win in ipairs(vim.api.nvim_list_wins()) do
                                bufs[vim.api.nvim_win_get_buf(win)] = true
                            end
                            return vim.tbl_keys(bufs)
                        end,
                    },
                    { name = "path", priority = 250 },
                }),
                performance = {
                    throttle = 30,
                    debounce = 30,
                    fetching_timeout = 200,
                    max_view_entries = 50,
                },
                experimental = { ghost_text = { hl_group = "Comment" } },
            })

            -- Command-line completion
            cmp.setup.cmdline({ "/", "?" }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = { { name = "buffer" } },
                window = {
                    completion = {
                        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
                        winhighlight = "Normal:Normal,FloatBorder:CmpBorder,CursorLine:CmpSel",
                    },
                },
            })
            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
                matching = { disallow_symbol_nonprefix_matching = false },
                window = {
                    completion = {
                        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
                        winhighlight = "Normal:Normal,FloatBorder:CmpBorder,CursorLine:CmpSel",
                    },
                },
            })
        end,
    },
}
