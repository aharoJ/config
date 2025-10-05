---@diagnostic disable: undefined-global
return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },

    config = function()
        local lint = require("lint")

        -- small helper: project root (fallback to cwd)
        local function project_root(patterns)
            local root = vim.fs.root(0, patterns)
            return root or vim.uv.cwd()
        end

        lint.linters_by_ft = {
            -- lua             = { "luacheck" }, -- brew install luarocks && luarocks install luacheck
            sh              = { "shellcheck" },
            bash            = { "shellcheck" },
            zsh             = { "zsh" },
            fish            = { "fish" },
            javascript      = { "eslint_d" },
            javascriptreact = { "eslint_d" },
            typescript      = { "eslint_d" },
            typescriptreact = { "eslint_d" },
            go              = { "golangcilint" },
            ruby            = { "rubocop" },
            php             = { "phpstan", "phpcs" },
            python          = { "ruff" },
            c               = { "clangtidy" },
            cpp             = { "clangtidy" },

            markdown        = { "markdownlint" },
            yaml            = { "yamllint" },
            json            = { "jsonlint" },
            xml             = { "tidy" },
            sql             = { "sqlfluff" },
            ["*"]           = { "codespell" },
        }

        -- eslint_d: prefer project root with config present
        local eslintd = lint.linters.eslint_d
        if eslintd then
            eslintd.args = {
                "--stdin", "--stdin-filename",
                function() return vim.api.nvim_buf_get_name(0) end,
                "--format", "json",
            }
            eslintd.cwd = function()
                return project_root({
                    ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.mjs",
                    ".eslintrc.json", "eslint.config.js", "package.json",
                })
            end
        end

        -- Checkstyle: try to locate a config file in the repo
        local checkstyle = lint.linters.checkstyle
        if checkstyle then
            checkstyle.args = {
                "-f", "xml",
                function()
                    local root = project_root({
                        "checkstyle.xml", "google_checks.xml", "sun_checks.xml",
                        "config/checkstyle/checkstyle.xml", ".checkstyle.xml",
                    })
                    local candidates = {
                        root .. "/checkstyle.xml",
                        root .. "/google_checks.xml",
                        root .. "/sun_checks.xml",
                        root .. "/config/checkstyle/checkstyle.xml",
                        root .. "/.checkstyle.xml",
                    }
                    for _, p in ipairs(candidates) do
                        if vim.uv.fs_stat(p) then return "-c=" .. p end
                    end
                    return "-c=/google_checks.xml" -- optional fallback if you ship one
                end,
            }
            -- checkstyle reads files, so keep defaults: stdin=false, append_fname=true
        end

        -- phpcs: JSON output, read from stdin
        local phpcs = lint.linters.phpcs
        if phpcs then
            phpcs.args = { "-q", "--report=json", "-" }
            phpcs.stdin = true
        end

        -- sqlfluff: only run if configured
        local sqlfluff = lint.linters.sqlfluff
        if sqlfluff then
            sqlfluff.args = { "lint", "-" }
            sqlfluff.stdin = true
            sqlfluff.condition = function()
                return vim.uv.fs_stat(project_root({ ".sqlfluff" }) .. "/.sqlfluff") ~= nil
            end
        end

        -- codespell: tone down noise
        local codespell = lint.linters.codespell
        if codespell then
            codespell.args = { "-", "--builtin", "clear,rare,informal,usage", "--ignore-words-list", "crate" }
            codespell.stdin = true
        end

        -- Limit Ruff to non-F rules to avoid overlap with Pyright
        local ruff = lint.linters.ruff
        if ruff then
            ruff.args = {
                "check",
                "--quiet",
                -- pick families you care about (no F):
                "--select=E,W,I,N,UP,B,C4,SIM,PIE,ISC,RUF",
                "--stdin-filename",
                function() return vim.api.nvim_buf_get_name(0) end,
                "--config",
                function()
                    -- prefer project ruff config if present, else run with args above
                    local root = (vim.fs.root(0, { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" }) or vim.uv.cwd())
                    local pp = root .. "/pyproject.toml"
                    local rt = root .. "/ruff.toml"
                    local rrt = root .. "/.ruff.toml"
                    if vim.uv.fs_stat(pp) then return pp end
                    if vim.uv.fs_stat(rt) then return rt end
                    if vim.uv.fs_stat(rrt) then return rrt end
                    return "/dev/null" -- no-op; keeps CLI happy
                end,
                "-",     -- read from stdin
            }
            ruff.stdin = true
        end


        -- debounce + autocmds
        local debounce_ms, timer = 150, vim.uv.new_timer()
        local function debounced_lint(bufnr)
            if timer then timer:stop() end
            timer:start(debounce_ms, 0, function()
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(bufnr) then
                        lint.try_lint()
                    end
                end)
            end)
        end

        vim.api.nvim_create_autocmd("BufWritePost", {
            callback = function(a) debounced_lint(a.buf) end,
        })
        vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave" }, {
            callback = function(a) debounced_lint(a.buf) end,
        })

        -- commands + toggles
        vim.api.nvim_create_user_command("Lint", function() lint.try_lint() end, {})
        vim.g.nvim_lint_disable = false
        vim.api.nvim_create_user_command("LintDisable", function(args)
            if args.bang then vim.b.nvim_lint_disable = true else vim.g.nvim_lint_disable = true end
        end, { bang = true })
        vim.api.nvim_create_user_command("LintEnable", function()
            vim.b.nvim_lint_disable = false; vim.g.nvim_lint_disable = false
        end, {})

        -- Respect toggles
        local orig = lint.try_lint
        lint.try_lint = function(...)
            if vim.g.nvim_lint_disable or vim.b.nvim_lint_disable then return end
            return orig(...)
        end

        -- (optional) slightly custom diagnostics for codespell
        local ns = lint.get_namespace("codespell")
        vim.diagnostic.config({ virtual_text = { prefix = "󰛨" }, signs = true, severity_sort = true }, ns)
    end,
}
