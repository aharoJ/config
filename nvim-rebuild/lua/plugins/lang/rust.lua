-- path: nvim/lua/plugins/lang/rust.lua
-- Description: rustaceanvim — dedicated Rust plugin that manages the rust-analyzer
--              LSP lifecycle. Same architectural pattern as nvim-jdtls for Java:
--              a dedicated plugin handles server startup because the standard LSP
--              setup misses too many Rust-specific features (grouped code actions,
--              runnables, macro expansion, rendered diagnostics, hover actions).
--
--              rustaceanvim is lazy by design — it uses its own internal ftplugin
--              to start rust-analyzer only when a Rust file is opened. Setting
--              lazy = false just means "load the plugin at startup" so it can
--              register its ftplugin; it does NOT start rust-analyzer eagerly.
--
--              rust-analyzer binary comes from rustup, NOT Mason:
--              `rustup component add rust-analyzer rustfmt clippy`
--              This ensures the analyzer version always matches your toolchain.
--
--              Formatting: rustfmt via conform (plugins/editor/formatting.lua).
--              Linting: clippy via rust-analyzer's check.command (no nvim-lint entry).
--              Completion: blink.cmp wires in automatically via LspAttach capabilities.
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F4. rustaceanvim with clippy, allFeatures,
--            Rust-specific keymaps via server.on_attach. rust_analyzer excluded from
--            mason-lspconfig automatic_enable (same pattern as jdtls).
--            | ROLLBACK: Delete this file, remove "rust_analyzer" from
--            automatic_enable.exclude in lsp.lua, remove rust entry from formatting.lua

return {
  "mrcjkb/rustaceanvim",
  version = "^7",
  lazy = false, -- WHY: rustaceanvim needs to register its ftplugin at startup.
                -- It does NOT start rust-analyzer until a .rs file is opened.

  -- WHY no dependencies on mason or lspconfig: rustaceanvim is fully
  -- self-contained. It finds rust-analyzer on PATH (installed by rustup),
  -- starts its own LSP client, and provides its own commands. It does NOT
  -- go through mason-lspconfig's auto-enable pipeline.

  init = function()
    -- ── rustaceanvim Configuration ──────────────────────────────────────
    -- WHY vim.g.rustaceanvim: This plugin reads its config from a global
    -- variable, not a .setup() call. This is set in init() so it's available
    -- before the plugin's ftplugin fires.
    vim.g.rustaceanvim = {

      -- ── Tool Settings ─────────────────────────────────────────────────
      tools = {
        -- WHY float_win_config: Consistent with our global vim.o.winborder
        -- and all other floating windows in the PDE.
        float_win_config = {
          border = "rounded",
        },
      },

      -- ── Server Configuration ──────────────────────────────────────────
      server = {
        -- ── on_attach ─────────────────────────────────────────────────
        -- WHY: Rust-specific keymaps that override or extend the global
        -- LspAttach bindings. Buffer-local keymaps set here take precedence
        -- over the global ones in plugins/editor/lsp.lua.
        on_attach = function(client, bufnr)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
          end

          -- ── Override K with hover actions ────────────────────────────
          -- WHY: Standard vim.lsp.buf.hover shows plain documentation.
          -- :RustLsp hover actions adds actionable links (go to impl,
          -- run test, etc.) in the hover popup. Strictly superior for Rust.
          map("n", "K", function() vim.cmd.RustLsp({ "hover", "actions" }) end,
            "Rust: Hover actions")

          -- ── Grouped code actions ────────────────────────────────────
          -- WHY: rust-analyzer groups code actions by category (e.g.,
          -- "Extract", "Generate", "Refactor"). vim.lsp.buf.code_action()
          -- can't render these groups — it flattens them into a single list.
          -- :RustLsp codeAction preserves the grouping.
          map({ "n", "v" }, "<leader>la", function() vim.cmd.RustLsp("codeAction") end,
            "Rust: Code action (grouped)")

          -- ── Runnables / Debuggables ─────────────────────────────────
          -- WHY: Lists test targets, binary targets, and examples from
          -- the Cargo project. Select one to run/debug inline. This is
          -- rust-analyzer's non-standard extension — no LSP equivalent.
          map("n", "<localleader>r", function() vim.cmd.RustLsp("runnables") end,
            "Rust: Runnables (tests/bins)")
          map("n", "<localleader>R", function() vim.cmd.RustLsp({ "runnables", bang = true }) end,
            "Rust: Rerun last runnable")
          map("n", "<localleader>d", function() vim.cmd.RustLsp("debuggables") end,
            "Rust: Debuggables")

          -- ── Macro expansion ─────────────────────────────────────────
          -- WHY: Recursively expands macros inline. Essential for debugging
          -- proc macros and understanding what derive macros generate.
          map("n", "<localleader>m", function() vim.cmd.RustLsp("expandMacro") end,
            "Rust: Expand macro")

          -- ── Rendered diagnostics ────────────────────────────────────
          -- WHY: Shows cargo's rendered diagnostic output in a float.
          -- The borrow checker's "help: consider..." messages are much
          -- more readable in cargo's rendered format than as LSP diagnostics.
          map("n", "<localleader>e", function() vim.cmd.RustLsp("renderDiagnostic") end,
            "Rust: Rendered diagnostic")
          map("n", "<localleader>E", function() vim.cmd.RustLsp("explainError") end,
            "Rust: Explain error")

          -- ── Cargo commands ──────────────────────────────────────────
          map("n", "<localleader>c", function() vim.cmd.RustLsp("openCargo") end,
            "Rust: Open Cargo.toml")
          map("n", "<localleader>f", function() vim.cmd.RustLsp("flyCheck") end,
            "Rust: Fly check (cargo clippy)")

          -- ── Structural editing ──────────────────────────────────────
          -- WHY: Smart join that handles trailing commas, braces, etc.
          -- Better than the standard J for Rust code.
          map("n", "<localleader>j", function() vim.cmd.RustLsp("joinLines") end,
            "Rust: Join lines (smart)")
          map("n", "<localleader>u", function() vim.cmd.RustLsp("moveItem", "up") end,
            "Rust: Move item up")
          map("n", "<localleader>i", function() vim.cmd.RustLsp("moveItem", "down") end,
            "Rust: Move item down")

          -- ── Formatting kill (belt-and-suspenders) ───────────────────
          -- WHY: rust-analyzer CAN format (it calls rustfmt internally).
          -- We kill LSP formatting here AND in the global LspAttach.
          -- conform.nvim with rustfmt is the sole formatting authority.
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,

        -- ── Default Settings ──────────────────────────────────────────
        default_settings = {
          ["rust-analyzer"] = {

            -- ── Clippy as check command ─────────────────────────────
            -- WHY: Default is `cargo check`. Setting to "clippy" runs
            -- `cargo clippy` instead, providing clippy lints as LSP
            -- diagnostics. This is the standard Rust community pattern.
            -- Zero extra tools — clippy runs inside rust-analyzer.
            check = {
              command = "clippy",
            },

            -- ── Enable all features ─────────────────────────────────
            -- WHY: Without this, diagnostics only cover the default
            -- feature set. With allFeatures = true, rust-analyzer checks
            -- code behind all feature gates. Essential for libraries
            -- with conditional compilation.
            cargo = {
              allFeatures = true,
            },

            -- ── Proc macro support ──────────────────────────────────
            -- WHY: Enables proc macro expansion. Without this, derive
            -- macros and attribute macros show as unresolved. The proc
            -- macro server runs as a separate process alongside rust-analyzer.
            procMacro = {
              enable = true,
            },

            -- ── Inlay hints tuning ──────────────────────────────────
            -- WHY: Rust's type inference is powerful but sometimes you
            -- want to see inferred types. These defaults keep hints
            -- available (toggled via <leader>lh from global LspAttach)
            -- without being overwhelming.
            inlayHints = {
              closingBraceHints = { minLines = 25 },
            },
          },
        },
      },
    }
  end,
}
