-- path: nvim/lua/plugins/editor/lsp.lua
-- Description: LSP foundation — Mason package manager, mason-lspconfig bridge,
--              nvim-lspconfig server data, LspAttach keymaps, and native diagnostics.
--              Server-specific settings live in lsp/<server>.lua (0.11+ file-based discovery).
-- CHANGELOG: 2026-02-10 | IDEI Phase A build. Clean slate from tracker. Mason v2 +
--            mason-lspconfig v2 + native LSP + capability-gated keymaps + diagnostics.
--            NO completion wiring (Phase B). NO formatting (Phase C). | ROLLBACK: Delete file
--            2026-02-11 | IDEI Phase F1. Added ts_ls + eslint to ensure_installed.
--            blink.cmp dependency already present from Phase B.
--            | ROLLBACK: Remove "ts_ls" and "eslint" from ensure_installed
--            2026-02-11 | IDEI Phase F2. Added jdtls to ensure_installed + exclude.
--            jdtls is Mason-installed but NOT auto-enabled — nvim-jdtls handles
--            startup via ftplugin/java.lua to avoid duplicate LSP instances.
--            | ROLLBACK: Remove "jdtls" from ensure_installed and exclude list
--            2026-02-12 | IDEI Phase F7. Added lemminx to ensure_installed.
--            Formatting capability KEPT (lemminx is ONLY XML formatter).
--            | ROLLBACK: Remove "lemminx" from ensure_installed, delete lsp/lemminx.lua
--            2026-02-12 | IDEI Phase F9. Added taplo to ensure_installed.
--            Formatting via conform (taplo CLI), LSP formatting killed.
--            | ROLLBACK: Remove "taplo" from ensure_installed, delete lsp/taplo.lua
--            2026-02-12 | IDEI Phase F10. Added fish_lsp to ensure_installed.
--            Formatting via conform (fish_indent CLI, ships with fish shell).
--            | ROLLBACK: Remove "fish_lsp" from ensure_installed, delete lsp/fish_lsp.lua
--            2026-02-12 | IDEI Phase F11. Added bashls to ensure_installed.
--            bashls auto-integrates shellcheck (500ms debounce).
--            Formatting via conform (shfmt CLI). DO NOT add shellcheck to nvim-lint.
--            | ROLLBACK: Remove "bashls" from ensure_installed, delete lsp/bashls.lua
--            2026-02-12 | IDEI Phase F12. Added jsonls to ensure_installed.
--            Formatting via conform (prettierd, already configured in Phase F1).
--            Schema validation via SchemaStore.nvim (new plugin dependency).
--            | ROLLBACK: Remove "jsonls" from ensure_installed, delete lsp/jsonls.lua
--            2026-02-12 | IDEI Phase F3. Added basedpyright (sole Python LSP).
--            ruff LSP DROPPED — systemic diagnostic overlap with basedpyright
--            (unused vars, undefined names, statement separation, string escapes)
--            was unsolvable without endless suppressions. ruff_format KEPT via conform.
--            | ROLLBACK: Remove "basedpyright" from ensure_installed,
--            delete lsp/basedpyright.lua
--            2026-02-12 | IDEI Phase F6. Added marksman (Markdown LSP).
--            Structural intelligence: links, goto def, references, document symbols,
--            TOC code action. Style linting via markdownlint-cli2 in nvim-lint (separate).
--            Formatting via prettierd (already Phase F1). Zero diagnostic overlap.
--            | ROLLBACK: Remove "marksman" from ensure_installed, delete lsp/marksman.lua
--            2026-02-12 | IDEI Phase F4. Added rust_analyzer to automatic_enable.exclude.
--            rustaceanvim manages rust-analyzer lifecycle (same pattern as nvim-jdtls).
--            rust-analyzer binary from rustup, NOT Mason — version must match toolchain.
--            DO NOT add rust_analyzer to ensure_installed (rustup manages the binary).
--            Formatting via rustfmt in conform. Clippy via rust-analyzer check.command.
--            | ROLLBACK: Remove "rust_analyzer" from automatic_enable.exclude,
--            delete plugins/lang/rust.lua, remove rust entry from formatting.lua
return {
	-- ── Mason: Package Manager for LSP Servers, Formatters, Linters ───────
	-- WHY: Single binary installer for the entire IDEI stack. Servers, formatters,
	-- and linters all managed from one place. No manual PATH wrangling.
	{
		"mason-org/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUpdate" },
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			ui = { border = "rounded" },
		},
	},

	-- ── Mason-LSPConfig v2: Auto-Enable Installed Servers ─────────────────
	-- WHY: mason-lspconfig v2 does ONE thing: auto-calls vim.lsp.enable() for
	-- every Mason-installed server. Server configs come from lsp/<server>.lua
	-- files (native 0.11+ auto-discovery) merged with nvim-lspconfig bundled configs.
	--
	-- WHAT CHANGED FROM LAST TIME:
	-- - Phase F4: rust_analyzer added to automatic_enable.exclude
	-- - rustaceanvim manages rust-analyzer (same as nvim-jdtls for Java)
	-- - rust_analyzer NOT in ensure_installed (rustup manages the binary)
	-- - No stylua/prettierd/google-java-format here (formatters are NOT LSP servers)
	{
		"mason-org/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason-org/mason.nvim",
			"neovim/nvim-lspconfig", -- Provides lsp/ config data for server discovery
			"saghen/blink.cmp", -- Phase B: ensures capabilities wired before servers start
		},
		opts = {
			-- Servers to auto-install. Each has a matching lsp/<n>.lua config file
			-- EXCEPT jdtls which uses ftplugin/java.lua via nvim-jdtls instead.
			ensure_installed = {
				"lua_ls", -- Lua (Neovim config) — Phase A
				"ts_ls", -- TypeScript/JavaScript/React/Next.js — Phase F1
				"eslint", -- ESLint as LSP (diagnostics + code actions) — Phase F1
				"jdtls", -- Java (Spring Boot) — Phase F2, started by nvim-jdtls
				"lemminx", -- XML (Maven POM, Spring config) — Phase F7
				"taplo", -- TOML (Cargo.toml, pyproject.toml) — Phase F9
				"fish_lsp", -- Fish shell (config scripts) — Phase F10
				"bashls", -- Bash/sh (shellcheck auto-integrated) — Phase F11
				"jsonls", -- JSON/JSONC (SchemaStore.nvim for schema intelligence) — Phase F12
				"basedpyright", -- Python type checking + LSP (sole Python server) — Phase F3
				"marksman", -- Markdown (structural: links, symbols, TOC) — Phase F6
			},
			-- WHY automatic_enable with exclude: v2 default auto-calls vim.lsp.enable()
			-- for every installed server. This is correct for lua_ls, ts_ls, eslint,
			-- marksman — they use the standard lsp/<server>.lua + vim.lsp.config pattern.
			--
			-- jdtls is EXCLUDED because nvim-jdtls handles startup via
			-- require("jdtls").start_or_attach() in ftplugin/java.lua. If we let
			-- mason-lspconfig also enable jdtls, TWO instances would start:
			-- 1. A basic one from vim.lsp.enable("jdtls") with default config
			-- 2. Our full one from ftplugin with bundles, workspace dirs, handlers
			-- This causes duplicate diagnostics, doubled completions, and confusion.
			-- The nvim-jdtls README explicitly warns about this conflict.
			--
			-- rust_analyzer is EXCLUDED because rustaceanvim manages the rust-analyzer
			-- lifecycle (same pattern as jdtls). rustaceanvim starts its own LSP client
			-- with Rust-specific extensions (grouped code actions, runnables, macro
			-- expansion). If mason-lspconfig also enables rust_analyzer, TWO instances
			-- start. Additionally, rust_analyzer is NOT in ensure_installed — the binary
			-- comes from rustup, not Mason, to prevent version mismatches.
			automatic_enable = {
				exclude = { "jdtls", "rust_analyzer" },
			},
		},
	},

	-- ── nvim-lspconfig: Server Configuration Data ─────────────────────────
	-- WHY: Even in 0.11+, nvim-lspconfig provides bundled server configs in its
	-- lsp/ directory. Our lsp/<server>.lua files EXTEND these defaults via
	-- vim.lsp.config() merge order: nvim-lspconfig defaults → our overrides.
	-- Without nvim-lspconfig, we'd have to define cmd, filetypes, root_markers
	-- for every server from scratch.
	--
	-- ARCHITECTURE: This spec has NO opts — all server configuration is either:
	-- 1. In lsp/<server>.lua files (auto-discovered by vim.lsp.config)
	-- 2. In ftplugin/<filetype>.lua for servers that need custom startup (jdtls)
	-- The only code here is the LspAttach autocmd for keymaps + diagnostics.
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			-- ── Diagnostics Configuration ─────────────────────────────────
			-- WHY here (not in a separate diagnostics.lua): Diagnostics are the
			-- native display layer for LSP errors/warnings. They're configured once,
			-- globally, and apply to every attached LSP client. No plugin needed.
			vim.diagnostic.config({
				-- ── Virtual Text (inline, after the line) ─────────────────
				virtual_text = true, -- LEAVE AS THIS
				-- ── Virtual Lines (multi-line diagnostic below the code) ──
				virtual_lines = false, -- HATED THIS!

				-- ── Signs (gutter icons) ─────────────────────────────────
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.INFO] = " ",
						[vim.diagnostic.severity.HINT] = " ",
					},
				},

				-- ── General ──────────────────────────────────────────────
				underline = true, -- Underline the affected code span
				update_in_insert = false, -- Don't update diagnostics while typing (noisy)
				severity_sort = true, -- Errors first, then warnings, then info/hints
				float = {
					border = "rounded", -- Consistent with vim.o.winborder
					source = true, -- Show which LSP/linter produced the diagnostic
				},
			})

			-- ── LspAttach Autocmd ─────────────────────────────────────────
			-- WHY: Capability-gated keymaps. Only create bindings when the attached
			-- server actually supports the feature. No "method not supported" errors.
			-- These are BUFFER-LOCAL — they only exist in buffers with an active LSP.
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
				callback = function(event)
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if not client then
						return
					end

					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, silent = true, desc = desc })
					end

					-- ── Navigation ────────────────────────────────────────────
					-- WHY: These are the core LSP navigation keymaps. 0.11+ provides
					-- defaults (grn, gra, grr, gri, gO) but we add explicit <leader>l
					-- namespace bindings for discoverability via which-key.
					if client:supports_method("textDocument/definition") then
						map("n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
					end
					if client:supports_method("textDocument/declaration") then
						map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
					end
					-- - grn → vim.lsp.buf.rename()
					-- - gra → vim.lsp.buf.code_action()
					-- - grr → vim.lsp.buf.references()
					-- - gri → vim.lsp.buf.implementation()
					-- - grt → vim.lsp.buf.type_definition()

					-- ── Navigation (we can delete these) ──────────────────────────
					if client:supports_method("textDocument/typeDefinition") then
						map("n", "<leader>ct", vim.lsp.buf.type_definition, "LSP: Type definition")
					end
					if client:supports_method("textDocument/implementation") then
						map("n", "<leader>ci", vim.lsp.buf.implementation, "LSP: Implementation")
					end
					if client:supports_method("textDocument/references") then
						map("n", "<leader>cr", vim.lsp.buf.references, "LSP: References")
					end

					-- ── Information ───────────────────────────────────────────
					if client:supports_method("textDocument/hover") then
						map("n", "K", vim.lsp.buf.hover, "LSP: Hover documentation")
					end
					if client:supports_method("textDocument/signatureHelp") then
						map("i", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature help")
					end

					-- ── Refactoring ───────────────────────────────────────────
					if client:supports_method("textDocument/rename") then
						map("n", "<leader>cn", vim.lsp.buf.rename, "LSP: Rename symbol")
					end
					if client:supports_method("textDocument/codeAction") then
						map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
					end

					-- ── Diagnostics ───────────────────────────────────────────
					map("n", "<leader>dd", vim.diagnostic.open_float, "Diagnostics: Line diagnostics")
					map("n", "[d", function()
						vim.diagnostic.jump({ count = -1 })
					end, "Diagnostics: Previous")
					map("n", "]d", function()
						vim.diagnostic.jump({ count = 1 })
					end, "Diagnostics: Next")
					map("n", "<leader>dl", vim.diagnostic.setloclist, "Diagnostics: Location list")

					-- ── Formatting Kill (belt-and-suspenders) ─────────────────
					-- WHY: Even though each lsp/<server>.lua and ftplugin/java.lua kills
					-- formatting individually, this is the GLOBAL safety net. If any
					-- future server forgets to disable formatting, this catches it.
					-- conform.nvim is the SOLE formatting authority (Phase C architecture).
					client.server_capabilities.documentFormattingProvider = false
					client.server_capabilities.documentRangeFormattingProvider = false

					-- ── Inlay Hints ───────────────────────────────────────────
					-- WHY toggle: Inlay hints are useful for unfamiliar code but noisy for
					-- code you know well. Toggle on demand rather than always-on.
					if client:supports_method("textDocument/inlayHint") then
						map("n", "<leader>ch", function()
							vim.lsp.inlay_hint.enable(
								not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
								{ bufnr = event.buf }
							)
						end, "Toggle inlay hints")
					end

					-- ── Document Highlight ────────────────────────────────────
					-- WHY: When cursor rests on a symbol, highlight other occurrences.
					-- Built-in to 0.11+ LSP client, no plugin needed.
					if client:supports_method("textDocument/documentHighlight") then
						local highlight_group = vim.api.nvim_create_augroup("UserLspHighlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							group = highlight_group,
							buffer = event.buf,
							callback = vim.lsp.buf.document_highlight,
						})
						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							group = highlight_group,
							buffer = event.buf,
							callback = vim.lsp.buf.clear_references,
						})
					end
				end,
				desc = "LSP: Configure keymaps and buffer settings on attach",
			})
		end,
	},
}
