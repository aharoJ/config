# 🔬 IDEI — Progress & Field Journal

> What actually happened. Bugs, decisions, learnings, and the WHY behind every pivot.
> This is the companion to `idei.progress.md` (the build plan).
> One is the map. This is the terrain.

---

## Phase A — LSP Foundation (Lua-only)

**Started:** 2026-02-10
**Completed:** 2026-02-11
**Status:** ✅ PASSED (Checkpoint A7 verified)

### What We Built

| Task | File                     | What It Does                                           |
| ---- | ------------------------ | ------------------------------------------------------ |
| A1   | `plugins/editor/lsp.lua` | mason.nvim — binary package manager                    |
| A2   | `plugins/editor/lsp.lua` | mason-lspconfig v2 — auto-enable bridge                |
| A3   | `plugins/editor/lsp.lua` | nvim-lspconfig — server config data (bundled defaults) |
| A4   | `plugins/editor/lsp.lua` | LspAttach autocmd — capability-gated keymaps           |
| A5   | `plugins/editor/lsp.lua` | vim.diagnostic.config() — native 0.11+ display         |
| A6   | `lsp/lua_ls.lua`         | Native server config for lua-language-server           |

### Research Findings (R1-R4)

| Item                            | Finding                                                                                                                                                                                         | Impact                                                           |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| R1 — blink.cmp manual trigger   | `completion.menu.auto_show = false` is the official API. `<C-Space>` calls `show`.                                                                                                              | Clean, documented, no hacks.                                     |
| R2 — mason-lspconfig v2 exclude | `automatic_enable = { exclude = { ... } }` works. But stylua isn't an LSP — it's a formatter. Formatters go through `:MasonInstall` directly, NOT through mason-lspconfig's `ensure_installed`. | Root cause of the stylua-as-LSP bug from the old config.         |
| R3 — conform format-on-save     | Just don't set `format_on_save` at all. No key = no behavior.                                                                                                                                   | Belt-and-suspenders: also kill LSP formatting caps in LspAttach. |
| R4 — mason-lspconfig v2 API     | `automatic_enable = true` is default. Auto-calls `vim.lsp.enable()` for installed servers.                                                                                                      | `handlers` and `setup_handlers()` are v1 API — removed in v2.    |

### Bugs Found & Fixed

#### Bug 1: Visual Diagnostic Duplication

- **Symptom:** Same diagnostic appeared twice on cursor line — once as inline `virtual_text`, once as `virtual_lines` below.
- **Root Cause:** `virtual_text = true` and `virtual_lines = { current_line = true }` both render on the cursor line simultaneously. Two renderers, one diagnostic.
- **First Fix (buggy):** CursorMoved autocmd that toggled `virtual_text = false` globally when cursor was on a diagnostic line. **Problem:** this killed virtual_text on ALL lines, not just cursor line.
- **Final Fix:** Native 0.11+ `current_line` option on virtual_text: `virtual_text = { current_line = false }` hides inline text on cursor line, `virtual_lines = { current_line = true }` shows detail. No autocmd needed. Two config lines.
- **Lesson:** Check if Neovim has a native solution before writing autocmds. The 0.11+ API is deeper than it looks.

### Decisions Made

| Decision                                                | Rationale                                                                                                                                     |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| No blink.cmp capability wiring in Phase A               | Decouples LSP from completion. LSP works fine without enhanced capabilities. Wire in Phase B.                                                 |
| Global formatting kill in LspAttach                     | Belt-and-suspenders: even if a future server config forgets `format.enable = false`, formatting is dead on arrival. Stolen from GPT feedback. |
| `vim.diagnostic.jump()` not `goto_next()`/`goto_prev()` | `goto_next`/`goto_prev` deprecated in 0.11+. Multiple feedback LLMs got this wrong.                                                           |
| `mason-org/` not `williamboman/`                        | GitHub org migrated. Three out of four feedback LLMs used the old org. Would cause stale installs.                                            |
| Lua-only `ensure_installed`                             | Every other server waits until Phase F. No phantom servers attaching unexpectedly.                                                            |

### Feedback Audit (GPT / Kimi / DeepSeek / Gemini)

| Source   | Stole                                                  | Dismissed                                                                                                                                        |
| -------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| GPT      | Global formatting capability kill in LspAttach         | `after/lsp/` path (wrong), deprecated `goto_prev`/`goto_next`, whitelist-only `automatic_enable`                                                 |
| Kimi     | Nothing                                                | Wrong GitHub org, `automatic_enable = false` fights the tool, hacked diagnostic config on lazy.nvim spec, auto-enabled inlay hints               |
| DeepSeek | Nothing                                                | Deprecated `lspconfig.setup()`, `hrsh7th/cmp-nvim-lsp` wrong plugin, manual `dofile()` reimplements native feature, cargo-culted lua paths       |
| Gemini   | Nothing (same formatting kill we already had from GPT) | Deprecated `lspconfig.setup()`, v1 `handlers` API, wrong GitHub org, no `{ clear = true }`, no `desc` on keymaps, `source = "always"` deprecated |

### Checkpoint A7 Results

| Check                              | Expected                | Actual                                                        |
| ---------------------------------- | ----------------------- | ------------------------------------------------------------- |
| `:checkhealth lsp` — lua_ls active | YOUR settings loaded    | ✅ `format.enable = false`, `diagnostics.globals = { "vim" }` |
| Clients on `.lua` files            | Exactly 1               | ✅ lua_ls (id: 1)                                             |
| Diagnostic per error               | 1 source per diagnostic | ✅ All from `Lua Diagnostics.`                                |
| Hover (`K`)                        | Works with border       | ✅                                                            |
| Rename (`grn`)                     | Works                   | ✅                                                            |
| Formatting capability              | `false`                 | ✅                                                            |
| No auto-format on save             | File saves as-is        | ✅                                                            |
| Startup time                       | < 50ms                  | ✅ 31ms                                                       |

### Cleanup Notes

Old Mason installs still present (auto-enabled by `automatic_enable = true`):
bashls, cssls, html, jdtls, jsonls, pyright, rust_analyzer, tailwindcss, ts_ls, yamlls.
These won't touch `.lua` files but should be uninstalled before Phase F to start clean.

```
:MasonUninstall bash-language-server css-lsp html-lsp typescript-language-server json-lsp pyright rust-analyzer tailwindcss-language-server yaml-language-server jdtls
```

---

## Phase B — Completion (Lua-only)

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (Checkpoint B1-B10 verified)

### What We Built

| Task | File                            | What It Does                                                       |
| ---- | ------------------------------- | ------------------------------------------------------------------ |
| B1   | `plugins/editor/completion.lua` | blink.cmp — manual-only completion engine                          |
| B2   | `plugins/editor/lsp.lua`        | Added `"saghen/blink.cmp"` as mason-lspconfig dependency           |
| B3   | `lsp/lua_ls.lua`                | Added `callSnippet/keywordSnippet = "Disable"` (server-side)       |
| B4   | `plugins/editor/completion.lua` | `transform_items` snippet filter (client-side belt-and-suspenders) |
| B5   | `lsp/lua_ls.lua`                | Added `workspace.library = { vim.env.VIMRUNTIME }` for API types   |

### Research Findings (R5-R7)

| Item                             | Finding                                                                                                                                                                                                              | Impact                                                                       |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| R5 — blink.cmp auto-capabilities | Saghen confirmed in Discussion #1802: blink.cmp v1 on 0.11+ auto-wires LSP capabilities via `plugin/blink-cmp.lua`. No manual `vim.lsp.config("*", { capabilities = ... })` needed.                                  | Eliminated tracker's pre-build note. Zero manual capability code.            |
| R6 — Dependency load order       | By listing blink.cmp as mason-lspconfig dependency, lazy.nvim loads it BEFORE servers start. Guarantees `plugin/blink-cmp.lua` runs its `vim.lsp.config("*")` before first server attachment.                        | Correct timing without `lazy = false`. Startup time preserved.               |
| R7 — lua_ls snippet kill switch  | `settings.Lua.completion.callSnippet/keywordSnippet = "Disable"` tells lua_ls to not generate snippet-type items at the source. Referenced in blink.cmp snippet docs. Some LSPs ignore client-side `snippetSupport`. | Server-side kill + client-side `transform_items` filter = zero snippet leak. |

### Bugs Found & Fixed

#### Bug 2: LSP Completions Missing — Only Buffer Words Appeared

- **Symptom:** After deploying blink.cmp, `<C-Space>` only showed buffer words (`lala`, `local`, `vim`). No LSP items (no `vim.api`, `vim.lsp`, etc.).
- **Initial Suspicion:** `transform_items` filter crashing silently, killing LSP source. Commented it out — same result. Eliminated.
- **Second Suspicion:** blink.cmp LSP source misconfigured. Checked `:checkhealth blink` — LSP source registered. Eliminated.
- **Isolation Test:** Set `auto_show = true` — still no LSP items. Eliminated blink.cmp trigger config.
- **Isolation Test:** Used native Neovim LSP completion (`vim.lsp.completion.enable()`) bypassing blink entirely — still no LSP items. **Proved blink.cmp was NOT the problem.**
- **Root Cause:** `workspace.library` was empty. `diagnostics.globals = { "vim" }` only suppresses "undefined global" warnings — it doesn't load Neovim's type definitions. lua_ls was attached and producing diagnostics, but had zero knowledge of what `vim` contains. No types = no completions.
- **Fix:** Added `workspace.library = { vim.env.VIMRUNTIME }` to `lsp/lua_ls.lua`. One line.
- **Lesson:** `globals = { "vim" }` ≠ "lua_ls knows the vim API." It just means "don't warn me about `vim` being undefined." The actual API types come from `VIMRUNTIME`. This is what `lazydev.nvim` handles automatically — but a single manual line works for Neovim-config-only use cases.

### Decisions Made

| Decision                                  | Rationale                                                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| No manual capability wiring               | blink.cmp auto-wires on 0.11+ via `plugin/blink-cmp.lua`. Manual `get_lsp_capabilities()` is unnecessary maintenance burden. (R5)                 |
| blink.cmp as mason-lspconfig dependency   | Guarantees correct load order (capabilities before servers) without `lazy = false`. Preserves startup time. (R6)                                  |
| `auto_show = false` (manual-only)         | Core IDEI principle: summon intelligence, don't be interrupted. `<C-Space>` is the only entry point.                                              |
| `preset = "default"` keymap               | `C-y` accept, `C-n/C-p` navigate, `C-e` dismiss. Vim muscle memory. No Tab/S-Tab (cargo-culty on HHKB).                                           |
| `preselect = true, auto_insert = false`   | First item highlighted (fast C-y accept) but nothing inserted until explicit acceptance. No phantom text.                                         |
| `documentation.auto_show = true`          | Once menu is manually opened, docs show immediately. No second keypress to read what a function does.                                             |
| Ghost text OFF                            | Visual noise when completion is manual-only. Defeats the purpose.                                                                                 |
| Snippets OFF (three layers)               | 1) Removed from `sources.default`. 2) lua_ls `callSnippet/keywordSnippet = "Disable"`. 3) `transform_items` filter. Belt-and-suspenders-and-belt. |
| Signature help OFF                        | Phase B validates completion in isolation. Signature help is a separate concern, enable later.                                                    |
| `vim.env.VIMRUNTIME` in workspace.library | Manual alternative to `lazydev.nvim`. Loads Neovim API types for lua_ls completions. One line, no plugin dependency. (Bug 2 fix)                  |
| Rust fuzzy matcher                        | `prefer_rust_with_warning` — pre-built aarch64-apple-darwin binary. ~6x faster than Lua. Free performance on M4 Max.                              |

### Feedback Audit (Grok / Kimi / DeepSeek / Gemini / ChatGPT)

| Source   | Stole                                                                                     | Dismissed                                                                                                                  |
| -------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Grok     | Nothing (triple-layer trigger protection is redundant, signature help deferred correctly) | Missing blink.cmp dependency → timing bug (capabilities not wired before server start)                                     |
| Kimi     | Nothing                                                                                   | `require("blink.cmp")` inside `lsp/lua_ls.lua` crashes if plugin not loaded; `preset = "none"` reimplements defaults worse |
| DeepSeek | Nothing                                                                                   | `lazy = false` violates startup rule; fabricated plenary dependency; double-setup anti-pattern                             |
| Gemini   | Nothing                                                                                   | Deprecated `use_nvim_cmp_as_default`; same `preset = "none"` + Tab/S-Tab issues as Kimi                                    |
| ChatGPT  | lua_ls `callSnippet/keywordSnippet = "Disable"`; `transform_items` snippet filter         | `VeryLazy` less precise than `InsertEnter` for completion loading                                                          |

### Checkpoint B1-B10 Results

| Check                      | Expected                                                          | Actual |
| -------------------------- | ----------------------------------------------------------------- | ------ |
| B1: `:checkhealth blink`   | Fuzzy = aarch64-apple-darwin, sources listed                      | ✅     |
| B2: Manual trigger         | `vim.` = no menu; `<C-Space>` = LSP items                         | ✅     |
| B3: No snippets            | Zero Snippet-kind items in menu                                   | ✅     |
| B4: Enhanced capabilities  | `labelDetailsSupport`, `resolveSupport`, `snippetSupport` present | ✅     |
| B5: Source labels          | LSP, Buffer, Path items present                                   | ✅     |
| B6: Cmdline completion     | `:check` and `/vim` completions work                              | ✅     |
| B7: Diagnostics regression | virtual_text, virtual_lines, hover, rename, refs all work         | ✅     |
| B8: Formatting still dead  | `documentFormattingProvider = false`                              | ✅     |
| B9: Startup time           | < 50ms                                                            | ✅     |
| B10: One tool per job      | Each concern = exactly 1 tool                                     | ✅     |

---

## Phase C — Formatting (Lua-only)

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (Checkpoint C1-C7 verified)

### What We Built

| Task | File                            | What It Does                                                       |
| ---- | ------------------------------- | ------------------------------------------------------------------ |
| C1   | `plugins/editor/formatting.lua` | conform.nvim — manual-only formatting engine                       |
| C2   | `plugins/editor/formatting.lua` | `<leader>cf` keymap — the ONLY path to formatting                  |
| C3   | `plugins/editor/formatting.lua` | `lsp_format = "never"` — triple kill on LSP formatting             |
| C4   | Mason (manual install)          | `:MasonInstall stylua` — formatter binary, NOT via mason-lspconfig |

### Research Findings (R8)

| Item                      | Finding                                                                                                                                                                                                                    | Impact                                                                   |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| R8 — conform lazy-loading | `keys` + `cmd` loading is sufficient. No `event` trigger needed since there's no format-on-save. 3 out of 4 feedback LLMs used `event = { "BufReadPre", "BufNewFile" }` which loads conform on every file open — wasteful. | Zero startup cost. Conform loads only on `<leader>cf` or `:ConformInfo`. |

### Bugs Found & Fixed

No bugs in Phase C. Clean deployment.

### Decisions Made

| Decision                                        | Rationale                                                                                                                                                            |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| No `format_on_save` key at all                  | Explicit omission is clearer than setting to `false` or `nil`. Conform never hooks into BufWritePre. User's strongest preference.                                    |
| `lsp_format = "never"` in `default_format_opts` | Belt-and-suspenders with Phase A's capability kill. Even if a server mistakenly had caps left, conform won't use it.                                                 |
| `<leader>cf` keymap (code format)               | Formatting is a code action. Lives in `<leader>c` namespace. Manual-only — the ONLY path to formatting.                                                              |
| Lazy-load on `keys` + `cmd` only                | No `event` trigger. Conform doesn't load until `<leader>cf` pressed or `:ConformInfo` run. Zero startup cost.                                                        |
| `async = true` in format call                   | Non-blocking format. stylua is fast enough on M4 Max that it feels synchronous anyway.                                                                               |
| stylua via `:MasonInstall`, NOT mason-lspconfig | Formatters are NOT LSP servers. mason-lspconfig is for LSP servers only. This was the root cause of the stylua-as-LSP bug from the old config. (R2 reinforced)       |
| No `prepend_args` for stylua                    | stylua reads `.stylua.toml` from project root automatically. CLI args would override project configs — bad for multi-project workflows.                              |
| No `ConformLspSafetyCheck` autocmd              | Duplicates Phase A's LspAttach formatting kill. If Phase A breaks, fix it there — don't patch from a second location. One tool per job applies to safety checks too. |
| No `vim.notify` callback on format              | Visual noise. You see the buffer change when formatting works. Conform already has built-in error reporting.                                                         |

### Feedback Audit (GPT / Grok / DeepSeek / Kimi / Claude / Gemini)

| Source   | Stole   | Dismissed                                                                                                     |
| -------- | ------- | ------------------------------------------------------------------------------------------------------------- |
| GPT      | Nothing | `log_level` is unnecessary clutter                                                                            |
| Grok     | N/A     | Presented our build                                                                                           |
| DeepSeek | Nothing | Fake `ensure_installed` on mason.nvim (doesn't exist); eager-loading via `event`; rewrote lsp.lua dangerously |
| Kimi     | Nothing | Duplicate LspAttach safety check; noisy notifications; deprecated `lsp_fallback` param; eager-loading         |
| Claude   | Nothing | Eager-loading; overwrote built-in `:ConformInfo`; `prepend_args` fights project configs                       |
| Gemini   | Nothing | `vim.notify` callback noise; `async = true` identical to ours; commented-out `prepend_args` (correct call)    |

### Checkpoint C1-C7 Results

| Check                         | Expected                                         | Actual |
| ----------------------------- | ------------------------------------------------ | ------ |
| C1: `:ConformInfo`            | Shows `Formatters for this buffer: stylua`       | ✅     |
| C2: Manual format works       | `<leader>cf` formats buffer                      | ✅     |
| C3: No format on save         | `:w` saves with bad formatting intact            | ✅     |
| C4: Visual range formatting   | `V` select + `<leader>cf` formats selection only | ✅     |
| C5: LSP formatting still dead | `documentFormattingProvider = false`             | ✅     |
| C6: One tool per job          | `:ConformInfo` shows ONLY stylua, no LSP         | ✅     |
| C7: Startup time              | < 50ms, conform lazy-loaded                      | ✅     |

### One-Tool-Per-Job Matrix (Lua) — Phase A+B+C Complete

| Concern        | Tool               | Count | Source          | Phase |
| -------------- | ------------------ | ----- | --------------- | ----- |
| Diagnostics    | lua_ls             | 1     | LSP             | A     |
| Completion     | blink.cmp ← lua_ls | 1     | plugin + LSP    | B     |
| Formatting     | stylua via conform | 1     | external binary | C     |
| Hover/Goto/Ref | lua_ls             | 1     | LSP             | A     |
| Rename         | lua_ls (grn)       | 1     | LSP             | A     |
| Linting        | lua_ls (built-in)  | 1     | LSP             | A     |
| Snippets       | OFF                | 0     | —               | B     |

✅ **Zero overlap.** No tool does another tool's job.

---

## Phase D — Linting (Lua-only)

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (Checkpoint D3 verified)

### What We Built

| Task | File                      | What It Does                                                |
| ---- | ------------------------- | ----------------------------------------------------------- |
| D1   | `plugins/editor/lint.lua` | nvim-lint — async linting engine, infrastructure            |
| D2   | `plugins/editor/lint.lua` | Empty `linters_by_ft` — Lua = lua_ls covers all diagnostics |
| D3   | `plugins/editor/lint.lua` | Auto-trigger autocmd (BufReadPost + BufWritePost)           |

### Research Findings

| Item                        | Finding                                                                                                                                                                                    | Impact                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| nvim-lint async behavior    | `lint.try_lint()` is async and safe to call unconditionally — no-op for filetypes without configured linters. BufReadPost + BufWritePost matches LSP passive diagnostic model.             | No manual trigger needed. Infrastructure ready for Phase F expansion.       |
| nvim-lint diagnostic source | nvim-lint uses a SEPARATE diagnostic namespace from LSP (mfussenegger/nvim-lint#826). Diagnostics from nvim-lint don't merge on the same line as LSP diagnostics — creates visual clutter. | Critical finding. This is WHY eslint runs as LSP in Phase F, not nvim-lint. |

### Bugs Found & Fixed

No bugs in Phase D. The file is infrastructure — empty `linters_by_ft` means nvim-lint loads but does nothing on Lua files. lua_ls remains the sole diagnostic source.

### Decisions Made

| Decision                                | Rationale                                                                                                                                        |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Empty linters_by_ft for Lua             | lua_ls provides complete Lua diagnostics. Adding an external linter would create duplicates with no benefit.                                     |
| BufReadPost + BufWritePost auto-trigger | Matches the passive LSP diagnostic model. Linting fires automatically like LSP diagnostics, not manually triggered.                              |
| No event = BufReadPre                   | Lint AFTER the buffer is loaded, not during. BufReadPost is the correct timing.                                                                  |
| nvim-lint reserved for non-LSP tools    | Tools without an LSP option (ruff, markdownlint) go through nvim-lint. Tools WITH an LSP option (eslint) use the LSP path for clean diagnostics. |

### Checkpoint D3 Results

| Check                            | Expected                     | Actual |
| -------------------------------- | ---------------------------- | ------ |
| Open `.lua` file with errors     | Diagnostics from lua_ls ONLY | ✅     |
| `require("lint").linters_by_ft`  | `{}`                         | ✅     |
| No double diagnostic on any line | Single source per diagnostic | ✅     |
| nvim-lint loaded                 | Plugin present, idle for Lua | ✅     |

---

## Phase E — Lua Toolchain Sign-Off

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (All E1-E5 verified)

### Sign-Off Results

| Check                          | Expected                               | Actual |
| ------------------------------ | -------------------------------------- | ------ |
| E1: One-tool-per-job matrix    | Each concern = exactly 1 tool          | ✅     |
| E2: Startup time               | < 50ms                                 | ✅     |
| E3: `:checkhealth` all green   | No errors                              | ✅     |
| E4: Zero duplicate diagnostics | One source per diagnostic per line     | ✅     |
| E5: Zero auto-format events    | `:w` saves as-is, no BufWritePre hooks | ✅     |

### Final Lua One-Tool-Per-Job Matrix (Signed Off)

| Concern        | Tool               | Count | Source          | Phase |
| -------------- | ------------------ | ----- | --------------- | ----- |
| Diagnostics    | lua_ls             | 1     | LSP             | A     |
| Completion     | blink.cmp ← lua_ls | 1     | plugin + LSP    | B     |
| Formatting     | stylua via conform | 1     | external binary | C     |
| Hover/Goto/Ref | lua_ls             | 1     | LSP             | A     |
| Rename         | lua_ls (grn)       | 1     | LSP             | A     |
| Linting        | lua_ls (built-in)  | 1     | LSP             | A     |
| Snippets       | OFF                | 0     | —               | B     |

✅ **Lua toolchain complete.** Green light for Phase F language expansion.

---

## Phase F — TypeScript + Tailwind CSS Language Expansion

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (user-verified: "flawless... beautiful and fast AF")

### What We Built

| Task | File                            | What It Does                                                             |
| ---- | ------------------------------- | ------------------------------------------------------------------------ |
| F1   | `lsp/ts_ls.lua`                 | Native server config — types, formatting kill, ignoredCodes, inlay hints |
| F2   | `lsp/eslint.lua`                | ESLint as LSP — lint diagnostics + code actions, formatting kill         |
| F3   | `lsp/tailwindcss.lua`           | Tailwind CSS — class completion, hover, validation, classRegex           |
| F4   | `plugins/editor/lsp.lua`        | Updated `ensure_installed` with ts_ls + eslint + tailwindcss             |
| F5   | `plugins/editor/formatting.lua` | Added prettierd/prettier for 13 web filetypes                            |
| F6   | Mason (manual install)          | `:MasonInstall prettierd`                                                |
| F0   | Mason cleanup                   | Uninstalled orphaned servers from old config                             |

### Research Methodology — Multi-LLM Competitive Analysis

Phase F used a novel approach: the same brief was given to 6 LLMs (GPT, Kimi, DeepSeek, Gemini, Claude A, Claude B). Each produced independent drafts of all config files. The drafts were audited line-by-line, best findings merged, and inferior approaches discarded. This caught several critical issues no single LLM found alone.

### Research Findings (R9-R15)

| Item                                       | Finding                                                                                                                                                                                                                                                                         | Impact                                                                         |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| R9 — Duplicate diagnostics prevention      | TypeScript codes 6133 ("declared but never read") and 6196 ("declared but never used") overlap with eslint's `@typescript-eslint/no-unused-vars`. Suppressing in ts_ls via `diagnostics.ignoredCodes = { 6133, 6196 }` prevents duplicate unused-var warnings on the same line. | Zero duplicate diagnostics between ts_ls and eslint. Claude A's best finding.  |
| R10 — Root detection for monorepos         | Explicit `root_markers` critical for monorepo support. ts*ls needs tsconfig.json/jsconfig.json/package.json/.git. eslint needs flat config (eslint.config.*) AND legacy (.eslintrc.\_) variants. tailwindcss needs tailwind.config.js/ts/mjs/cjs and postcss.config variants.   | Servers attach at correct project root, not repo root.                         |
| R11 — Monorepo safety (workingDirectories) | eslint-lsp `workingDirectories.mode = "auto"` auto-detects working directory from config location. Prevents silent failures in workspace subdirectories (4.8.0→4.10.0 bug).                                                                                                     | eslint works correctly in monorepo subdirectories.                             |
| R12 — ESLint as LSP vs nvim-lint           | nvim-lint uses SEPARATE diagnostic namespace from LSP (mfussenegger/nvim-lint#826). Diagnostics don't merge on the same line — creates visual clutter. eslint-lsp merges into vim.diagnostic AND provides code actions (EslintFixAll, disable-rule) that nvim-lint can't.       | eslint runs as LSP. nvim-lint reserved for tools without LSP option (ruff).    |
| R13 — Import preferences                   | `preferTypeOnlyAutoImports = true` for cleaner tree-shaking. `importModuleSpecifierPreference` intentionally omitted — default ("shortest") respects tsconfig paths aliases (@/components). Setting "relative" fights Next.js aliases.                                          | Clean imports, respects project aliases.                                       |
| R14 — Tailwind classRegex                  | `experimental.classRegex` enables Tailwind intellisense inside utility functions (clsx, cn, cva) and tagged templates (tw``). Without this, completions only work in `className=""`attributes, not in shadcn/ui's`cn()` pattern.                                                | Tailwind completions work everywhere you write classes, not just in JSX props. |
| R15 — format.enable belt-and-suspenders    | ts_ls settings block has `format.enable = false` for BOTH typescript AND javascript sections, in addition to on_attach capability kill AND global LspAttach kill. Three-layer formatting kill per server, same pattern as lua_ls.                                               | Four-layer formatting prevention. Borderline paranoid, exactly right.          |

### Bugs Found & Fixed

No bugs in Phase F. Clean deployment — all three LSP servers attached correctly on first try. "Flawless... beautiful and fast AF."

### Decisions Made

| Decision                                    | Rationale                                                                                                                                                            |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ts_ls (not vtsls, not denols)               | Standard TypeScript LSP. vtsls is experimental. denols is for Deno, not Node/React/Next.js.                                                                          |
| ESLint as LSP (not nvim-lint)               | nvim-lint#826: separate diagnostic namespace = visual clutter. LSP gives clean vim.diagnostic merge + code actions (fix, disable rule, EslintFixAll, show docs).     |
| tailwindcss as third LSP client             | Zero overlap: ts_ls=types, eslint=lint, tailwindcss=class intelligence. Three servers, three distinct concerns.                                                      |
| ignoredCodes {6133, 6196} in ts_ls          | Prevents duplicate unused-var diagnostics. eslint's `@typescript-eslint/no-unused-vars` is more configurable (underscore patterns, args: "after-used").              |
| Explicit root_markers on all three servers  | Monorepo safety. Default root detection can attach at the wrong project level.                                                                                       |
| workingDirectories.mode = "auto" for eslint | Auto-detects CWD from eslint config location. Avoids 4.8.0→4.10.0 workingDirectories silent failure bug.                                                             |
| codeActionOnSave = false for eslint         | Manual control only. Use `gra` for individual fixes, `:EslintFixAll` for bulk. No auto-fix surprises.                                                                |
| classRegex for clsx/cn/cva/tw``             | Without this, Tailwind completions only work in `className=""`. Misses shadcn/ui's `cn()` pattern and other utility function patterns.                               |
| preferTypeOnlyAutoImports = true            | Cleaner tree-shaking. Explicit type vs value imports. Standard for modern React/Next.js.                                                                             |
| Omit importModuleSpecifierPreference        | Default "shortest" respects tsconfig paths aliases (@/components). Setting "relative" would fight Next.js path aliases.                                              |
| prettierd with prettier fallback            | Daemon wrapper stays warm between invocations (~10x faster cold start). `stop_after_first = true` uses first available.                                              |
| `local prettier` variable in formatting.lua | Used across 13 filetypes. Avoids typos in the fallback chain. Not DRY worship — it's a genuinely shared, genuinely stable constant.                                  |
| No dedicated jsonls/yamlls/html/cssls       | prettierd handles formatting. ts_ls handles JSON type checking on imports. Tailwind handles CSS class intelligence. Separate LSPs deferred unless explicit need.     |
| F0 Mason cleanup before Phase F             | GPT's operational catch. Orphaned servers from old config would auto-attach via `automatic_enable = true`. Clean slate prevents phantom attachments.                 |
| Multi-LLM competitive research              | 6 LLMs produce independent drafts → audit → merge best findings. Catches issues no single source finds alone. Claude A won research, Claude B won constitution form. |

### Feedback Audit (GPT / Kimi / DeepSeek / Gemini / Claude A / Claude B)

**Rankings (Phase F TypeScript + Tailwind):**

| Rank | LLM      | Stole                                                                                                                    | Dismissed                                                                                            |
| ---- | -------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| 1    | Claude A | `ignoredCodes`, comprehensive `root_markers`, `workingDirectories.mode = "auto"`, `preferTypeOnlyAutoImports`, #826 cite | Missing `format.enable = false` in settings (relied only on on_attach)                               |
| 2    | Claude B | Complete files with CHANGELOGs/ROLLBACKs, `format.enable = false` belt-and-suspenders, `graphql` + `mdx` coverage        | Missed ignoredCodes, root_markers, workingDirectories — the three biggest production bug preventions |
| 3    | GPT      | F0 Mason cleanup reminder (operational thinking), `mdx` filetype                                                         | Raw `workspace/executeCommand` for EslintFixAll (unnecessary), too sparse on ts_ls config            |
| 4    | Kimi     | `includeInlayParameterNameHints = "literals"` (less noisy option), `useFlatConfig = true`                                | `importModuleSpecifier = "relative"` fights aliases, fragments not complete files                    |
| 5    | Gemini   | Nothing                                                                                                                  | `hostInfo = "neovim"` (does nothing), circular EslintFixAll, no root_markers, added unrequested LSPs |
| 6    | DeepSeek | Nothing                                                                                                                  | No response provided                                                                                 |

### Checkpoint F Results (User-Verified)

| Check                          | Expected                                            | Actual |
| ------------------------------ | --------------------------------------------------- | ------ |
| `:LspInfo` on `.tsx` file      | Exactly 3 clients: ts_ls + eslint + tailwindcss     | ✅     |
| Type error diagnostics         | Source: ts_ls                                       | ✅     |
| Lint violation diagnostics     | Source: eslint only (6133/6196 suppressed in ts_ls) | ✅     |
| `<C-Space>` in `className=""`  | Tailwind class completions                          | ✅     |
| `<C-Space>` inside `cn("...")` | Tailwind completions (classRegex working)           | ✅     |
| Hover over Tailwind class      | Shows generated CSS preview                         | ✅     |
| Invalid class like "flex-coll" | Tailwind diagnostic warning                         | ✅     |
| `gra` on eslint diagnostic     | Code actions (fix, disable rule, show docs)         | ✅     |
| `<leader>cf` format            | prettierd formats via conform                       | ✅     |
| `:w` saves without formatting  | No auto-format on save                              | ✅     |
| `documentFormattingProvider`   | `false` for all three servers                       | ✅     |
| Startup time                   | < 50ms                                              | ✅     |

### One-Tool-Per-Job Matrix (TypeScript + Tailwind) — Phase F Complete

| Concern                 | Tool                    | Count | Source          | Phase |
| ----------------------- | ----------------------- | ----- | --------------- | ----- |
| Diagnostics (types)     | ts_ls                   | 1     | LSP             | F     |
| Diagnostics (lint)      | eslint                  | 1     | LSP             | F     |
| Diagnostics (classes)   | tailwindcss             | 1     | LSP             | F     |
| Completion (TS/JS)      | blink.cmp ← ts_ls       | 1     | plugin + LSP    | B+F   |
| Completion (Tailwind)   | blink.cmp ← tailwindcss | 1     | plugin + LSP    | B+F   |
| Formatting              | prettierd via conform   | 1     | external binary | F     |
| Hover/Goto/Ref          | ts_ls                   | 1     | LSP             | F     |
| Hover (Tailwind CSS)    | tailwindcss             | 1     | LSP             | F     |
| Rename                  | ts_ls                   | 1     | LSP             | F     |
| Code Actions (refactor) | ts_ls                   | 1     | LSP             | F     |
| Code Actions (lint fix) | eslint                  | 1     | LSP             | F     |
| Snippets                | OFF                     | 0     | —               | B     |

✅ **Three LSP servers, zero overlap.** ts_ls owns type system, eslint owns lint rules, tailwindcss owns utility class intelligence.

### Post-Phase-F Cleanup Notes

Two minor documentation gaps identified in final audit (non-blocking):

1. **lint.lua description stale:** Header still mentions "infrastructure for Phase F when eslint arrives" — but eslint went the LSP route. Commented-out `typescript = { "eslint" }` lines are dead code. Should update comments to reflect eslint-as-LSP decision and remove dead TS/JS comments. File remains correct infrastructure for future Python (`ruff`) and Markdown (`markdownlint`).

2. **lsp.lua CHANGELOG missing tailwindcss:** Phase F CHANGELOG mentions adding ts_ls + eslint but not tailwindcss to `ensure_installed`. Minor paper trail gap.

Neither affects functionality. Addressable in next cleanup pass.

---

## Current State — File Inventory

```
~/.config/nvim/
├── init.lua                              ← require("core") — one-liner
├── lsp/
│   ├── lua_ls.lua                        ← Phase A + B (diagnostics, completion, snippet kill)
│   ├── ts_ls.lua                         ← Phase F (types, formatting kill, ignoredCodes, inlay hints)
│   ├── eslint.lua                        ← Phase F (lint diagnostics, code actions, workingDirectories)
│   └── tailwindcss.lua                   ← Phase F (class completion, hover, validation, classRegex)
└── lua/
    ├── core/                             ← Phase 1 (core PDE rebuild)
    ├── config/
    │   └── lazy.lua                      ← lazy.nvim bootstrap
    └── plugins/
        └── editor/
            ├── lsp.lua                   ← Phase A (Mason, mason-lspconfig, LspAttach, diagnostics)
            ├── completion.lua            ← Phase B (blink.cmp, manual trigger, snippet kill)
            ├── formatting.lua            ← Phase C + F (conform, stylua + prettierd)
            └── lint.lua                  ← Phase D (nvim-lint, infrastructure, idle for Lua)
```

**Mason-installed tools:**

- LSP servers (via `ensure_installed`): lua_ls, ts_ls, eslint, tailwindcss
- Formatters (via `:MasonInstall`): stylua, prettierd

---

_IDEI Field Journal — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
_Phases A-F complete | TypeScript + Tailwind CSS verified_
