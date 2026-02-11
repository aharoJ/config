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

| Task | File | What It Does |
|------|------|-------------|
| A1 | `plugins/editor/lsp.lua` | mason.nvim — binary package manager |
| A2 | `plugins/editor/lsp.lua` | mason-lspconfig v2 — auto-enable bridge |
| A3 | `plugins/editor/lsp.lua` | nvim-lspconfig — server config data (bundled defaults) |
| A4 | `plugins/editor/lsp.lua` | LspAttach autocmd — capability-gated keymaps |
| A5 | `plugins/editor/lsp.lua` | vim.diagnostic.config() — native 0.11+ display |
| A6 | `lsp/lua_ls.lua` | Native server config for lua-language-server |

### Research Findings (R1-R4)

| Item | Finding | Impact |
|------|---------|--------|
| R1 — blink.cmp manual trigger | `completion.menu.auto_show = false` is the official API. `<C-Space>` calls `show`. | Clean, documented, no hacks. |
| R2 — mason-lspconfig v2 exclude | `automatic_enable = { exclude = { ... } }` works. But stylua isn't an LSP — it's a formatter. Formatters go through `:MasonInstall` directly, NOT through mason-lspconfig's `ensure_installed`. | Root cause of the stylua-as-LSP bug from the old config. |
| R3 — conform format-on-save | Just don't set `format_on_save` at all. No key = no behavior. | Belt-and-suspenders: also kill LSP formatting caps in LspAttach. |
| R4 — mason-lspconfig v2 API | `automatic_enable = true` is default. Auto-calls `vim.lsp.enable()` for installed servers. | `handlers` and `setup_handlers()` are v1 API — removed in v2. |

### Bugs Found & Fixed

#### Bug 1: Visual Diagnostic Duplication
- **Symptom:** Same diagnostic appeared twice on cursor line — once as inline `virtual_text`, once as `virtual_lines` below.
- **Root Cause:** `virtual_text = true` and `virtual_lines = { current_line = true }` both render on the cursor line simultaneously. Two renderers, one diagnostic.
- **First Fix (buggy):** CursorMoved autocmd that toggled `virtual_text = false` globally when cursor was on a diagnostic line. **Problem:** this killed virtual_text on ALL lines, not just cursor line.
- **Final Fix:** Native 0.11+ `current_line` option on virtual_text: `virtual_text = { current_line = false }` hides inline text on cursor line, `virtual_lines = { current_line = true }` shows detail. No autocmd needed. Two config lines.
- **Lesson:** Check if Neovim has a native solution before writing autocmds. The 0.11+ API is deeper than it looks.

### Decisions Made

| Decision | Rationale |
|----------|-----------|
| No blink.cmp capability wiring in Phase A | Decouples LSP from completion. LSP works fine without enhanced capabilities. Wire in Phase B. |
| Global formatting kill in LspAttach | Belt-and-suspenders: even if a future server config forgets `format.enable = false`, formatting is dead on arrival. Stolen from GPT feedback. |
| `vim.diagnostic.jump()` not `goto_next()`/`goto_prev()` | `goto_next`/`goto_prev` deprecated in 0.11+. Multiple feedback LLMs got this wrong. |
| `mason-org/` not `williamboman/` | GitHub org migrated. Three out of four feedback LLMs used the old org. Would cause stale installs. |
| Lua-only `ensure_installed` | Every other server waits until Phase F. No phantom servers attaching unexpectedly. |

### Feedback Audit (GPT / Kimi / DeepSeek / Gemini)

| Source | Stole | Dismissed |
|--------|-------|-----------|
| GPT | Global formatting capability kill in LspAttach | `after/lsp/` path (wrong), deprecated `goto_prev`/`goto_next`, whitelist-only `automatic_enable` |
| Kimi | Nothing | Wrong GitHub org, `automatic_enable = false` fights the tool, hacked diagnostic config on lazy.nvim spec, auto-enabled inlay hints |
| DeepSeek | Nothing | Deprecated `lspconfig.setup()`, `hrsh7th/cmp-nvim-lsp` wrong plugin, manual `dofile()` reimplements native feature, cargo-culted lua paths |
| Gemini | Nothing (same formatting kill we already had from GPT) | Deprecated `lspconfig.setup()`, v1 `handlers` API, wrong GitHub org, no `{ clear = true }`, no `desc` on keymaps, `source = "always"` deprecated |

### Checkpoint A7 Results

| Check | Expected | Actual |
|-------|----------|--------|
| `:checkhealth lsp` — lua_ls active | YOUR settings loaded | ✅ `format.enable = false`, `diagnostics.globals = { "vim" }` |
| Clients on `.lua` files | Exactly 1 | ✅ lua_ls (id: 1) |
| Diagnostic per error | 1 source per diagnostic | ✅ All from `Lua Diagnostics.` |
| Hover (`K`) | Works with border | ✅ |
| Rename (`grn`) | Works | ✅ |
| Formatting capability | `false` | ✅ |
| No auto-format on save | File saves as-is | ✅ |
| Startup time | < 50ms | ✅ 31ms |

### Cleanup Notes

Old Mason installs still present (auto-enabled by `automatic_enable = true`):
bashls, cssls, html, jdtls, jsonls, pyright, rust_analyzer, tailwindcss, ts_ls, yamlls.
These won't touch `.lua` files but should be uninstalled before Phase F to start clean.

```
:MasonUninstall bash-language-server css-lsp html-lsp typescript-language-server json-lsp pyright rust-analyzer tailwindcss-language-server yaml-language-server jdtls
```

---

## Phase B — Completion (Lua-only)

**Started:** —
**Status:** ⬜ NOT STARTED

### Pre-Build Notes
- blink.cmp manual trigger: `completion.menu.auto_show = false` (confirmed in R1)
- Sources: lsp + path + buffer (no snippets initially)
- Wire capabilities to LSP via `vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })`
- Snippets OFF: tracker decision

---

## Phase C — Formatting (Lua-only)

**Started:** —
**Status:** ⬜ NOT STARTED

### Pre-Build Notes
- conform.nvim, NO `format_on_save` key at all
- Manual format: `<leader>cf`
- stylua for Lua (conform only, NOT LSP — lua_ls formatting already disabled)
- LSP formatting caps already killed globally in Phase A LspAttach

---

## Phase D — Linting (Lua-only)

**Started:** —
**Status:** ⬜ NOT STARTED

### Pre-Build Notes
- nvim-lint installed but idle for Lua (lua_ls covers diagnostics)
- Empty `linters_by_ft` — Lua needs no external linter

---

## Phase E — Lua Toolchain Sign-Off

**Started:** —
**Status:** ⬜ NOT STARTED

### Target One-Tool-Per-Job Matrix

| Concern | Tool | Count | Source |
|---------|------|-------|--------|
| Diagnostics | lua_ls | 1 | LSP |
| Completion | blink.cmp ← lua_ls | 1 | plugin + LSP |
| Formatting | stylua via conform | 1 | external binary |
| Hover/Goto/Ref | lua_ls | 1 | LSP |
| Rename | lua_ls (grn) | 1 | LSP |
| Linting | lua_ls (built-in) | 1 | LSP |
| Snippets | OFF | 0 | — |

---

_IDEI Field Journal — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
