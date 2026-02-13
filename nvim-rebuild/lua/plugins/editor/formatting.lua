-- path: nvim/lua/plugins/editor/formatting.lua
-- Description: conform.nvim — formatting engine. Manual-only triggers.
--              <leader>cf formats entire buffer (normal mode).
--              <leader>f formats visual selection (visual mode).
--              NO format-on-save. NO LSP formatting (killed in Phase A LspAttach).
--              Formatters: stylua for Lua, prettierd for TypeScript/JavaScript/web,
--              google-java-format for Java, rustfmt for Rust, taplo for TOML,
--              fish_indent for Fish, shfmt for sh/bash, sql_formatter for SQL.
-- CHANGELOG: 2026-02-11 | Phase C build. Manual trigger only. stylua for Lua.
--            | ROLLBACK: Delete file
--            2026-02-11 | Phase F1. Added prettierd (with prettier fallback) for
--            TypeScript, JavaScript, TSX, JSX, JSON, HTML, CSS, SCSS, YAML, Markdown.
--            | ROLLBACK: Remove all non-lua entries from formatters_by_ft
--            2026-02-11 | Phase F2. Added google-java-format for Java with --aosp
--            flag (4-space indent, matches Java convention in core/autocmds.lua).
--            | ROLLBACK: Remove java entry from formatters_by_ft, remove formatters block
--            2026-02-12 | IDEI Phase F7. Smart LSP fallback in <leader>cf for filetypes
--            without a conform formatter (XML/lemminx). No behavior change for existing
--            languages — conform still runs with lsp_format = "never" when a formatter exists.
--            | ROLLBACK: Revert <leader>cf to Phase F2 version (always lsp_format = "never")
--            2026-02-12 | IDEI Phase F9. Added taplo for TOML formatting.
--            | ROLLBACK: Remove toml entry from formatters_by_ft
--            2026-02-12 | IDEI Phase F10. Added fish_indent for Fish shell formatting.
--            fish_indent ships with fish shell (not a Mason package).
--            | ROLLBACK: Remove fish entry from formatters_by_ft
--            2026-02-12 | IDEI Phase F11. Added shfmt for sh/bash formatting.
--            shfmt configured with 2-space indent (-i 2) and case indent (-ci).
--            Formatter-specific config via formatters = {} section.
--            | ROLLBACK: Remove sh/bash entries from formatters_by_ft,
--            remove formatters.shfmt section
--            2026-02-12 | IDEI Phase F4. Added rustfmt for Rust formatting.
--            rustfmt ships with rustup (not Mason). conform reads Cargo.toml
--            edition automatically. No formatter config block needed.
--            | ROLLBACK: Remove rust entry from formatters_by_ft
--            2026-02-13 | Split keymaps: <leader>cf (normal → buffer), <leader>f
--            (visual → selection). Extracted shared format_with_fallback() local
--            to eliminate duplicate function bodies. Conform handles visual range
--            detection internally via '< '> marks — no manual range code needed.
--            Guarded LSP fallback to XML-only — prevents accidental LSP formatting
--            if a future server exposes formatting capability.
--            | ROLLBACK: Replace both keys with single <leader>cf in mode = { "n", "v" },
--            inline the function body, delete format_with_fallback local.
--            For LSP guard rollback: revert else branch to unconditional
--            vim.lsp.buf.format() call

-- WHY a local: Used 6 times across filetypes. Avoids typos in the fallback chain.
-- prettierd is the daemon wrapper (stays warm between invocations, ~10x faster cold start).
-- prettier is the fallback if prettierd isn't installed. stop_after_first = true means
-- conform uses the FIRST available formatter, not both.
local prettier = { "prettierd", "prettier", stop_after_first = true }

-- WHY a local: Shared by <leader>cf (normal) and <leader>f (visual). Same logic,
-- different trigger context. In visual mode, conform detects the selection internally
-- and formats only the range (for formatters that support it — stylua, prettierd, rustfmt).
-- Formatters without range support (shfmt, google-java-format, fish_indent, taplo)
-- will format the entire buffer regardless of visual selection.
local function format_with_fallback()
    local conform = require("conform")
    -- WHY: Check if conform has a formatter for this buffer's filetype.
    -- Most filetypes (Lua, TS, Java, Python) have explicit conform formatters.
    -- XML is the exception — lemminx is the ONLY formatter, and it's an LSP.
    -- This detects "no conform formatter" and falls back to vim.lsp.buf.format().
    --
    -- ARCHITECTURAL NOTE: This does NOT change behavior for ANY existing language.
    -- If a conform formatter exists → conform runs with lsp_format = "never" (unchanged).
    -- If no conform formatter exists AND filetype is xml → LSP formatting (lemminx).
    -- If no conform formatter AND not xml → warning notification, no formatting.
    -- This prevents accidental LSP formatting from sneaking in via future servers.
    local formatters = conform.list_formatters(0)
    if #formatters > 0 then
        -- Conform has a formatter — use it, never LSP (standard path)
        conform.format({
            bufnr = 0,
            lsp_format = "never",
            async = false,
            timeout_ms = 3000,
        })
    else
        -- No conform formatter — ONLY allow LSP formatting for XML (lemminx).
        -- WHY guarded: Prevents accidental LSP formatting if a future server
        -- exposes formatting capability. One tool per job — if a filetype needs
        -- formatting, add it to formatters_by_ft explicitly.
        if vim.bo.filetype == "xml" then
            vim.lsp.buf.format({
                async = false,
                timeout_ms = 3000,
            })
        else
            vim.notify("No conform formatter for ft=" .. vim.bo.filetype, vim.log.levels.WARN)
        end
    end
end

return {
    "stevearc/conform.nvim",
    -- WHY these load triggers: cmd for :ConformInfo diagnostics.
    -- keys for lazy-loading only when you actually format.
    -- No event trigger — conform doesn't need to load until you press the keymap.
    cmd = { "ConformInfo" },
    keys = {
        -- WHY split keymaps: <leader>cf is the conscious "format everything" action.
        -- <leader>f in visual is the quick "format just this" action. Conform handles
        -- visual range detection internally — same function, different ergonomic intent.
        { "<leader>cf", format_with_fallback, mode = "n", desc = "[code] format" },
        { "<leader>f", format_with_fallback, mode = "v", desc = "[code] format range" },
    },
    opts = {
        -- ── Formatters by Filetype ──────────────────────────────────────────
        -- WHY: Each filetype maps to exactly ONE formatter (or fallback chain).
        -- stylua for Lua (Phase C). prettierd for everything web (Phase F1).
        -- google-java-format for Java (Phase F2). One tool per job — no LSP
        -- formatting, no overlap.
        formatters_by_ft = {
            -- Phase C (Lua)
            lua = { "stylua" },
            -- Phase F1 (TypeScript/JavaScript ecosystem)
            typescript = prettier,
            javascript = prettier,
            typescriptreact = prettier,
            javascriptreact = prettier,
            -- Phase F1 (Web formats prettier handles natively)
            json = prettier,
            jsonc = prettier,
            html = prettier,
            css = prettier,
            scss = prettier,
            yaml = prettier,
            markdown = prettier,
            graphql = prettier,
            java = { "google-java-format" },      -- Phase F2 (Java)
            -- python = { "black" },              -- future phase
            toml = { "taplo" },                   -- Phase F9 (TOML)
            fish = { "fish_indent" },             -- Phase F10 (Fish shell)
            sh = { "shfmt" },                     -- Phase F11 (sh)
            bash = { "shfmt" },                   -- Phase F11 (bash)
            sql = { "sql_formatter" },
            rust = { "rustfmt" },                 -- Phase F4 (Rust — rustfmt via rustup, NOT Mason)
        },
        -- ── Formatter-Specific Configuration ────────────────────────────────
        formatters = {
            shfmt = {
                -- WHY: shfmt defaults to tabs. 2-space indent everywhere.
                -- -i 2 = 2-space indent, -ci = indent switch/case bodies
                prepend_args = { "-i", "2", "-ci" },
            },
        },

        -- ── Default Format Options ──────────────────────────────────────────
        -- WHY lsp_format = "never": LSP formatting is dead. Phase A killed the
        -- capability in LspAttach, server configs have format.enable = false, and
        -- conform also refuses to delegate to LSP. Triple kill. One tool per job.
        default_format_opts = {
            lsp_format = "never",
        },

        -- ── NO format_on_save ───────────────────────────────────────────────
        -- WHY ABSENT (not even set to false): The IDEI principle is manual-only
        -- formatting. Omitting the key entirely means conform never hooks into
        -- BufWritePre. No auto-formatting. Ever. You format when YOU decide.
        -- format_on_save = DO NOT ADD THIS KEY

        -- ── Notifications ───────────────────────────────────────────────────
        notify_on_error = true,           -- Know when formatting fails
        notify_no_formatters = true,      -- Know when no formatter is configured for a filetype
    },
}
