---@diagnostic disable: undefined-global, undefined-doc-name
-- path: ~/.config/nvim/lua/plugins/formatting/conform.lua

return {
    "stevearc/conform.nvim",
    event = { "BufWritePre" }, -- lazy-load right before save
    cmd = { "ConformInfo" },   -- optional helper UI
    keys = {
        {
            "<leader>f",
            function()
                require("conform").format({ async = true, lsp_format = "fallback" })
            end,
            mode = { "n", "x" },
            desc = "Format buffer / range",
        },
    },

    init = function()
        -- Use Conform as formatexpr (so motions like gq use it)
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,

    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
        ---------------------------------------------------------------------------
        -- choose formatters per filetype
        ---------------------------------------------------------------------------
        formatters_by_ft = {
            -- LUA
            lua             = { "stylua" },

            -- BASH / SH
            sh              = { "shfmt" },

            -- JS/TS
            javascript      = { "prettierd", "prettier", "eslint_d", stop_after_first = true },
            typescript      = { "prettierd", "prettier", "eslint_d", stop_after_first = true },
            javascriptreact = { "prettierd", "prettier", "eslint_d", stop_after_first = true },
            typescriptreact = { "prettierd", "prettier", "eslint_d", stop_after_first = true },

            -- GO
            go              = { "goimports", "gofmt" }, -- you had staticcheck (diagnostics) before; see nvim-lint below
            asm             = { "asmfmt" },

            -- RUBY
            ruby            = { "rubocop" },

            -- PHP
            php             = { "php_cs_fixer" },

            -- FISH
            fish            = { "fish_indent" },

            -- MARKDOWN
            markdown        = { "markdownlint", "prettierd", "prettier", "injected" },

            -- PYTHON
            python          = function(bufnr)
                local conform = require("conform")
                if conform.get_formatter_info("ruff_format", bufnr).available then
                    return { "ruff_format" }
                else
                    return { "isort", "black" }
                end
            end,

            -- XML
            xml             = { "tidy" }, -- custom def below if your tidy isn’t in PATH

            -- SQL
            sql             = { "pg_format" },

            -- C#
            cs              = { "csharpier" },

            -- C / C++
            c               = { "clang_format" },
            cpp             = { "clang_format" },

            -- JSON / YAML
            json            = { "jq" },
            yaml            = { "yamlfmt" },

            -- JAVA via LSP (your JDTLS)
            java            = { lsp_format = "prefer" },

            -- Default: run on everything else
            ["_"]           = { "trim_whitespace" },
        },

        ---------------------------------------------------------------------------
        -- sane defaults for calls (used by :w autoformat and <leader>f)
        ---------------------------------------------------------------------------
        default_format_opts = {
            -- Use Conform formatters first; if none, fall back to LSP
            lsp_format = "fallback",
            timeout_ms = 1000,
        },

        ---------------------------------------------------------------------------
        -- format-on-save: fast, respects buffer/global toggles (see commands below)
        ---------------------------------------------------------------------------
        format_on_save = function(bufnr)
            -- example ignore list (edit as you like)
            local ignore = { "sql" }
            if vim.tbl_contains(ignore, vim.bo[bufnr].filetype) then
                return
            end
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                return
            end
            return { lsp_format = "fallback", timeout_ms = 500 }
        end,

        -- optional: async formatting after save for very slow formatters
        -- format_after_save = { lsp_format = "fallback" },

        -- quiet logs unless formatter fails
        log_level = vim.log.levels.ERROR,
        notify_on_error = true,
        notify_no_formatters = true,

        ---------------------------------------------------------------------------
        -- per-formatter tweaks (examples)
        ---------------------------------------------------------------------------
        formatters = {
            shfmt = { append_args = { "-i", "2" } },
            -- you can pin prettier parser per ft via options.ft_parsers, etc.
            -- see docs’ "Formatter options" section
        },
    },

    config = function(_, opts)
        require("conform").setup(opts)

        -- quick toggles (from official recipes)
        vim.api.nvim_create_user_command("FormatDisable", function(args)
            if args.bang then
                vim.b.disable_autoformat = true
            else
                vim.g.disable_autoformat = true
            end
        end, { desc = "Disable autoformat-on-save", bang = true })

        vim.api.nvim_create_user_command("FormatEnable", function()
            vim.b.disable_autoformat = false
            vim.g.disable_autoformat = false
        end, { desc = "Re-enable autoformat-on-save" })

        -- optional :Format command that supports range formatting asynchronously
        vim.api.nvim_create_user_command("Format", function(cmdargs)
            local range = nil
            if cmdargs.count ~= -1 then
                local end_line = vim.api.nvim_buf_get_lines(0, cmdargs.line2 - 1, cmdargs.line2, true)[1]
                range = { start = { cmdargs.line1, 0 }, ["end"] = { cmdargs.line2, end_line:len() } }
            end
            require("conform").format({ async = true, lsp_format = "fallback", range = range })
        end, { range = true })
    end,
}
