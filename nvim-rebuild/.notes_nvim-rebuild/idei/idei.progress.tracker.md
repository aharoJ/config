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
- **Post-F2 Update:** User settled on `virtual_text = true` (always visible) + `virtual_lines = false` (never show). Simpler, cleaner. Signs + underlines + inline text is the right balance without layout shift.
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

No bugs in Phase D.

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

---

## Phase F1 — TypeScript + Tailwind CSS Language Expansion

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

Phase F used a novel approach: the same brief was given to 6 LLMs (GPT, Kimi, DeepSeek, Gemini, Claude A, Claude B). Each produced independent drafts of all config files. The drafts were audited line-by-line, best findings merged, and inferior approaches discarded.

### Feedback Audit (Phase F1 — TypeScript + Tailwind)

| Rank | LLM      | Stole                                                                                                                    | Dismissed                                                                                            |
| ---- | -------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| 1    | Claude A | `ignoredCodes`, comprehensive `root_markers`, `workingDirectories.mode = "auto"`, `preferTypeOnlyAutoImports`, #826 cite | Missing `format.enable = false` in settings (relied only on on_attach)                               |
| 2    | Claude B | Complete files with CHANGELOGs/ROLLBACKs, `format.enable = false` belt-and-suspenders, `graphql` + `mdx` coverage        | Missed ignoredCodes, root_markers, workingDirectories — the three biggest production bug preventions |
| 3    | GPT      | F0 Mason cleanup reminder (operational thinking), `mdx` filetype                                                         | Raw `workspace/executeCommand` for EslintFixAll (unnecessary), too sparse on ts_ls config            |
| 4    | Kimi     | `includeInlayParameterNameHints = "literals"` (less noisy option), `useFlatConfig = true`                                | `importModuleSpecifier = "relative"` fights aliases, fragments not complete files                    |
| 5    | Gemini   | Nothing                                                                                                                  | `hostInfo = "neovim"` (does nothing), circular EslintFixAll, no root_markers, added unrequested LSPs |
| 6    | DeepSeek | Nothing                                                                                                                  | No response provided                                                                                 |

### Checkpoint F1 Results (User-Verified)

| Check                          | Expected                                            | Actual |
| ------------------------------ | --------------------------------------------------- | ------ |
| `:LspInfo` on `.tsx` file      | Exactly 3 clients: ts_ls + eslint + tailwindcss     | ✅     |
| Type error diagnostics         | Source: ts_ls                                       | ✅     |
| Lint violation diagnostics     | Source: eslint only (6133/6196 suppressed in ts_ls) | ✅     |
| `<C-Space>` in `className=""`  | Tailwind class completions                          | ✅     |
| `<C-Space>` inside `cn("...")` | Tailwind completions (classRegex working)           | ✅     |
| Hover over Tailwind class      | Shows generated CSS preview                         | ✅     |
| `gra` on eslint diagnostic     | Code actions (fix, disable rule, show docs)         | ✅     |
| `<leader>cf` format            | prettierd formats via conform                       | ✅     |
| `:w` saves without formatting  | No auto-format on save                              | ✅     |
| `documentFormattingProvider`   | `false` for all three servers                       | ✅     |
| Startup time                   | < 50ms                                              | ✅     |

---

## Phase F2 — Java Language Expansion

**Started:** 2026-02-11
**Completed:** 2026-02-11
**Status:** ✅ PASSED (user-verified: `:checkhealth vim.lsp` + `:ConformInfo` clean)

### What We Built

| Task | File                            | What It Does                                                        |
| ---- | ------------------------------- | ------------------------------------------------------------------- |
| F2-1 | `ftplugin/java.lua`             | jdtls launch config via nvim-jdtls start_or_attach (the heart)      |
| F2-2 | `plugins/lang/java.lua`         | nvim-jdtls lazy.nvim spec — ft = java, no config (ftplugin owns it) |
| F2-3 | `plugins/editor/lsp.lua`        | Added jdtls to ensure_installed + automatic_enable.exclude          |
| F2-4 | `plugins/editor/formatting.lua` | Added java = google-java-format (2-space, default Google style)     |
| F2-5 | Mason (manual install)          | `:MasonInstall jdtls google-java-format`                            |

### Research Methodology — Multi-LLM Competitive Analysis (Java)

Same process as Phase F1: GPT, DeepSeek, and Kimi independently produced Java LSP plans. All three converged on nvim-jdtls over nvim-java. Findings merged, errors caught.

### Research Findings (R16-R18)

| Item                                   | Finding                                                                                                                                                                                                                                                                                                        | Impact                                                                                      |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| R16 — nvim-java vs nvim-jdtls          | nvim-java is "batteries included" (nui.nvim, custom Mason registry, bundled DAP/test/Spring). Violates one-tool-per-job. Custom registry caused version pinning issues (GitHub #164, #362, #398). Its own README says "if you love customizing, try nvim-jdtls." LazyVim, LunarVim, NvChad all use nvim-jdtls. | nvim-jdtls selected. Explicit, debuggable, community standard.                              |
| R17 — ftplugin vs plugins/lang pattern | nvim-jdtls's `start_or_attach()` must run on FileType java. ftplugin/ is the standard Neovim mechanism. Plugin spec is just `ft = "java"` (ensures plugin is loaded). All config lives in ftplugin. LazyVim uses this exact pattern.                                                                           | ftplugin/java.lua for config, plugins/lang/java.lua is a minimal spec.                      |
| R18 — Dual-attachment prevention       | mason-lspconfig v2 auto-calls `vim.lsp.enable("jdtls")` for any Mason-installed server. This starts a BASIC jdtls with default config. ftplugin ALSO starts jdtls via `start_or_attach`. Result: TWO clients. nvim-jdtls README explicitly warns. GitHub Discussion #654 confirms.                             | `automatic_enable = { exclude = { "jdtls" } }` in mason-lspconfig. One jdtls, full control. |

### Bugs Found & Fixed

No bugs in Phase F2. Clean deployment — jdtls attached correctly on first try with per-project workspace, Lombok agent, all settings verified via `:checkhealth vim.lsp`.

### Decisions Made

| Decision                                   | Rationale                                                                                                                                                        |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nvim-jdtls over nvim-java                  | KISS, explicit, no nui.nvim bloat, no custom Mason registry. Full control over cmd, workspace dirs, bundles. Community standard (LazyVim, LunarVim, NvChad).     |
| ftplugin/java.lua for jdtls config         | jdtls needs per-project workspace dirs, root detection, Lombok agent. ftplugin is the standard Neovim mechanism. Plugin spec is minimal loader.                  |
| jdtls excluded from automatic_enable       | Prevents dual-attachment. Mason installs the binary, nvim-jdtls handles startup. One jdtls, full control.                                                        |
| google-java-format default style (2-space) | User preference: 2-space everywhere except Python. Removed --aosp flag. Default Google style = 2-space.                                                          |
| `<leader>J` namespace for Java extras      | nvim-jdtls provides organize imports, extract variable/constant/method. Keymaps are buffer-local, Java-only.                                                     |
| Lombok javaagent mandatory                 | Spring Boot + Lombok is the standard stack. Without agent, jdtls shows false errors on @Data/@Builder classes. Mason bundles lombok.jar with jdtls package.      |
| Per-project workspace dirs                 | `~/.cache/nvim/jdtls/<project>/workspace`. Prevents cross-project state corruption (phantom errors, stale classpath, corrupted indexes).                         |
| java.format.enabled = false                | Triple kill: 1) server-side format disabled, 2) on_attach capability kill, 3) conform `lsp_format = "never"`. Same pattern as ts_ls and eslint.                  |
| starThreshold = 9999                       | Never use wildcard imports. Explicit imports > `import java.util.*`. Professional habit, clean code.                                                             |
| Debugging/testing deferred                 | ftplugin bundles architecture supports adding java-debug-adapter + vscode-java-test later without restructuring. Commented-out bundle code ready for activation. |
| No Spring Boot LSP                         | Deferred to future phase. jdtls provides core Java intelligence. Spring Boot extension (JavaHello/spring-boot.nvim) can be added later if explicit need arises.  |

### Feedback Audit (Phase F2 — Java)

| Rank | LLM      | Stole   | Dismissed                                                                                                                                                                                                       |
| ---- | -------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | GPT      | Nothing | Redundant FileType autocmd in config function (duplicate execution with ftplugin); mason-registry API (unnecessary complexity); formatter name fallback chain (nonexistent variant)                             |
| 2    | Kimi     | Nothing | Already aligned on every decision — nvim-jdtls, ftplugin pattern, google-java-format, bundle architecture. Best analysis, no steals needed.                                                                     |
| 3    | DeepSeek | Nothing | `vim.lsp.start()` instead of `start_or_attach()` (broken — no client reuse); lspconfig dependency in ftplugin (unnecessary); duplicate keymaps overlapping LspAttach; wrong Lombok claim; plenary hallucination |

### Checkpoint F2 Results (User-Verified)

| Check                               | Expected                                                    | Actual |
| ----------------------------------- | ----------------------------------------------------------- | ------ |
| `:checkhealth vim.lsp` — Active     | Exactly 1 jdtls client                                      | ✅     |
| jdtls NOT in Enabled Configurations | ftplugin started it, not mason-lspconfig                    | ✅     |
| Root directory                      | `~/.repository/StudyWithMe`                                 | ✅     |
| Lombok javaagent in cmd             | `--jvm-arg=-javaagent:.../lombok.jar`                       | ✅     |
| Per-project workspace               | `~/.cache/nvim-rebuild/jdtls/StudyWithMe/workspace`         | ✅     |
| `java.format.enabled`               | `false`                                                     | ✅     |
| All settings present                | favoriteStaticMembers, filteredTypes, importOrder, codeLens | ✅     |
| `:ConformInfo`                      | `google-java-format ready (java)`                           | ✅     |
| No auto-format on save              | `:w` saves as-is                                            | ✅     |
| Diagnostics working                 | "local variable lala is not used" warning on cursor line    | ✅     |
| Error detection                     | "right cannot be resolved to a variable" with underlines    | ✅     |

### Post-Phase-F2 Preference Changes

Two user preferences finalized during Java validation:

1. **Diagnostic display:** Settled on `virtual_text = true` + `virtual_lines = false`. virtual_lines was too intrusive (pushes buffer down when cursor lands on diagnostic lines). Signs + underlines + inline virtual_text is the right balance.

2. **Indent preference:** 2-space everywhere. Removed C/C++/C#/Rust from the 4-space autocmds.lua override. Only Python stays at 4-space (PEP 8). google-java-format runs with default Google style (2-space), no --aosp flag.

---

## Phase F3 — Python Language Expansion

**Started:** 2026-02-12
**Completed:** 2026-02-12
**Status:** ✅ PASSED (zero duplicate diagnostics, single-server architecture)

### What We Built

| Task | File                            | What It Does                                                             |
| ---- | ------------------------------- | ------------------------------------------------------------------------ |
| F3-1 | `lsp/basedpyright.lua`          | Native server config — types, hover, goto, diagnostics (sole Python LSP) |
| F3-2 | `plugins/editor/lsp.lua`        | Added basedpyright to `ensure_installed`                                 |
| F3-3 | `plugins/editor/formatting.lua` | Added python = ruff_format via conform                                   |
| F3-4 | Mason (manual install)          | `:MasonInstall basedpyright ruff`                                        |

### Research Findings (R25 — The Ruff Overlap Problem)

| Item                              | Finding                                                                                                                                                                                                                                                                                                                                                                                      | Impact                                                               |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| R25 — basedpyright + ruff overlap | Systemic diagnostic overlap extends far beyond unused imports. Affected rules: F401↔reportUnusedImport, F841↔reportUnusedVariable, B018↔reportUnusedExpression, F821↔reportUndefinedVariable, E702↔parser errors, W605↔reportInvalidStringEscapeSequence, PLC0414, RUF013, RUF016. Community has been playing whack-a-mole for 1+ year (basedpyright#203, ruff-lsp#384, LazyVim#5818). | ruff LSP dropped entirely. basedpyright as sole Python LSP.          |
| Parser-level conflicts unsolvable | basedpyright's Python parser catches syntax errors like statement separation (E702). These are NOT diagnostic rules — they're fundamental parser errors. Cannot be suppressed via `diagnosticSeverityOverrides`. No config can fix this.                                                                                                                                                     | Proved whack-a-mole is futile. Some overlaps have no solution.       |
| Community patterns all flawed     | LazyVim/LunarVim/Helix all tried different approaches: selective rule suppression (tedious, incomplete), `python.analysis.ignore = ['*']` (kills ALL type checking), ruff-only (loses type checking). No clean boundary exists between the two servers' diagnostic domains.                                                                                                                  | Confirmed: the two-server Python approach is architecturally broken. |

### Bugs Found & Fixed

#### Bug 3: Duplicate Diagnostics — basedpyright + ruff

- **Symptom:** Same errors appeared twice with different wording from different sources:
  - `"num0" is not defined` (basedpyright) + `Undefined name 'num0'` (ruff F821)
  - `Statements must be separated...` (basedpyright parser) + `Simple statements must be...` (ruff E702)
- **First Attempt:** Added `F821` to ruff `init_options.settings.lint.ignore`. Eliminated F821 duplicates but E702 still duplicated.
- **Second Attempt:** Researched deeper. Discovered E702 is a parser-level conflict — basedpyright's parser catches statement separation as a fundamental syntax error, not a diagnostic rule. Cannot be suppressed on either side.
- **Research:** Searched community solutions across basedpyright issues, ruff issues, LazyVim discussions, Helix forums, Reddit threads. All paths lead to whack-a-mole.
- **Final Fix:** Dropped ruff as LSP entirely. basedpyright is sole Python LSP. ruff_format kept via conform (CLI formatter, no LSP needed).
- **Lesson:** Two LSP servers with overlapping diagnostic domains is architecturally broken for Python. Unlike TypeScript (ts_ls=types, eslint=lint — clean boundary), basedpyright and ruff both claim ownership of the same diagnostic space. The only clean solution is one server.

### Decisions Made

| Decision                                      | Rationale                                                                                                                                                                                                      |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ruff LSP DROPPED                              | Systemic diagnostic overlap with basedpyright. Parser errors (E702), F821, F841, W605 all duplicate. Community whack-a-mole for 1+ year. No clean boundary exists between the two servers.                     |
| basedpyright as sole Python LSP               | `"standard"` mode catches real bugs: type errors, undefined names, unused imports, syntax errors. Sufficient for secondary language (Python is scripting/tooling, not primary like Java/TS).                   |
| ruff_format via conform (CLI, no LSP)         | ruff_format is a standalone CLI formatter. Doesn't need ruff LSP to run. Manual-only pattern consistent with all other languages.                                                                              |
| basedpyright overlap suppressions REMOVED     | Initial config had `diagnosticSeverityOverrides` suppressing F401/F841/B018 to avoid ruff overlap. With ruff dropped, basedpyright should report ALL its diagnostics. Cleaner config, no phantom suppressions. |
| Future ruff linting path: nvim-lint if needed | If deeper ruff linting needed later, add ruff to nvim-lint as CLI linter with curated rule set excluding basedpyright overlaps. But for secondary language use, basedpyright `"standard"` is sufficient.       |

### Checkpoint F3 Results

| Check                            | Expected                       | Actual |
| -------------------------------- | ------------------------------ | ------ |
| `:LspInfo` on `.py` file         | Exactly 1 client: basedpyright | ✅     |
| Type error diagnostics           | Source: basedpyright           | ✅     |
| Undefined name detection         | `"num0" is not defined`        | ✅     |
| Unused import/variable detection | basedpyright warnings          | ✅     |
| Zero duplicate diagnostics       | One source per diagnostic      | ✅     |
| `:ConformInfo` on `.py` file     | `ruff_format ready (python)`   | ✅     |
| `<leader>cf` format              | ruff_format runs via conform   | ✅     |
| `:w` saves without formatting    | No auto-format on save         | ✅     |
| `documentFormattingProvider`     | `false`                        | ✅     |

---

## Current State — File Inventory

```
~/.config/nvim/
├── init.lua                              ← require("core") — one-liner
├── ftplugin/
│   └── java.lua                          ← Phase F2 (jdtls launch via nvim-jdtls)
├── lsp/
│   ├── lua_ls.lua                        ← Phase A + B (diagnostics, completion, snippet kill)
│   ├── ts_ls.lua                         ← Phase F1 (types, formatting kill, ignoredCodes, inlay hints)
│   ├── eslint.lua                        ← Phase F1 (lint diagnostics, code actions, workingDirectories)
│   ├── tailwindcss.lua                   ← Phase F1 (class completion, hover, validation, classRegex)
│   ├── basedpyright.lua                  ← Phase F3 (sole Python LSP — types, diagnostics, hover)
│   ├── lemminx.lua                       ← Phase F7 (XML — all concerns)
│   ├── yamlls.lua                        ← Phase F8 (YAML — SchemaStore.nvim integration)
│   ├── taplo.lua                         ← Phase F9 (TOML — Cargo.toml, pyproject.toml)
│   ├── fish_lsp.lua                      ← Phase F10 (Fish shell)
│   ├── bashls.lua                        ← Phase F11 (Bash — shellcheck auto-integrated)
│   └── jsonls.lua                        ← Phase F12 (JSON — SchemaStore.nvim, validate.enable)
└── lua/
    ├── core/                             ← Phase 1 (core PDE rebuild)
    ├── config/
    │   └── lazy.lua                      ← lazy.nvim bootstrap
    └── plugins/
        ├── editor/
        │   ├── lsp.lua                   ← Phase A + F1-F12 (Mason, mason-lspconfig, LspAttach, diagnostics)
        │   ├── completion.lua            ← Phase B (blink.cmp, manual trigger, snippet kill)
        │   ├── formatting.lua            ← Phase C + F1-F3 (conform: stylua + prettierd + google-java-format + ruff_format + shfmt + fish_indent + taplo)
        │   └── lint.lua                  ← Phase D (nvim-lint, infrastructure, idle for Lua)
        ├── lang/
        │   └── java.lua                  ← Phase F2 (nvim-jdtls plugin spec, ft = java)
        └── ui/
            └── schemastore.lua           ← Phase F8/F12 (SchemaStore.nvim for jsonls + yamlls)
```

**Mason-installed tools:**

- LSP servers (via `ensure_installed`): lua_ls, ts_ls, eslint, tailwindcss, jdtls, basedpyright, lemminx, yaml-language-server, taplo, fish-lsp, bash-language-server, json-lsp
- Formatters (via `:MasonInstall`): stylua, prettierd, google-java-format, ruff, shfmt

---

_IDEI Field Journal — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
_Phases A-F3 complete | Lua + TypeScript + Tailwind + Java + Python verified_
_Phases F7-F12 complete | XML + YAML + TOML + Fish + Bash + JSON verified_
