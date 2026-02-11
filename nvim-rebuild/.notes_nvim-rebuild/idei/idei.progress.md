# 🧠 NVIM — IDE Intelligence Build Tracker

> Editor Intelligence bundle for the PDE rebuild.
> Every piece isolated. Every tool earns its place. One tool per job. Zero overlap.
> Lua-first validation, then expand language by language.

---

## Philosophy — Lessons from the Wreckage

**What went wrong last time:**

1. Over-complicated LSP config — beautiful but impossible to debug
2. Format-on-save enabled by default — violated user preference
3. stylua attached as BOTH LSP and conform formatter — duplicate tool, same job
4. lsp/ directory in wrong location — native configs silently ignored
5. mason-lspconfig auto-enabled 12 servers including unused ones
6. Duplicate diagnostics across tsx/jsx/python/lua — couldn't isolate source
7. nvim-lspconfig bundled defaults merging silently — phantom settings appeared

**What we're doing differently:**

- **Lua-first**: Every component validated on Lua files before touching other languages
- **One tool per job matrix**: Every filetype has exactly ONE provider per concern
- **Manual-only formatting**: NEVER auto-format. `<leader>cf` is the ONLY path to formatting
- **Manual-trigger completion**: Menu appears when summoned, not while typing
- **No snippets initially**: Add AFTER completion is rock-solid and controllable
- **No AI completion**: Copilot deferred to future injection phase
- **Isolation principle**: Each file controls exactly one concern. When something breaks, you know WHERE

---

## Architecture — The IDEI Stack

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR FINGERS                         │
│              (keymaps trigger everything)                │
├─────────────────────────────────────────────────────────┤
│  COMPLETION          │  DIAGNOSTICS    │  FORMATTING    │
│  blink.cmp           │  vim.diagnostic │  conform.nvim  │
│  (manual trigger)    │  (native 0.11+) │  (manual only) │
│  sources: lsp,       │  virtual_text + │  external      │
│    path, buffer      │  virtual_lines  │  formatters    │
├──────────────────────┤  (no plugin)    ├────────────────┤
│  SNIPPETS            │                 │  LINTING       │
│  vim.snippet (native)│                 │  nvim-lint     │
│  (Phase 2 — off      │                 │  (sparse —     │
│   initially)         │                 │   LSP covers   │
│                      │                 │   most)        │
├──────────────────────┴─────────────────┴────────────────┤
│                    LSP LAYER                            │
│  vim.lsp.config() + vim.lsp.enable()  (native 0.11+)   │
│  lsp/<server>.lua    (file-based auto-discovery)        │
│  nvim-lspconfig      (bundled server configs only)      │
├─────────────────────────────────────────────────────────┤
│                 INSTALLATION LAYER                      │
│  mason.nvim          (binary installer)                 │
│  mason-lspconfig     (auto-enable bridge)               │
├─────────────────────────────────────────────────────────┤
│                    NEOVIM 0.11+                         │
│  Built-in: LSP client, diagnostics, snippets, comments  │
└─────────────────────────────────────────────────────────┘
```

---

## Build Phases — Incremental, Testable

### Phase A — LSP Foundation (Lua-only validation)

| #   | Task                                                                            | File                     | Status | Validated |
| --- | ------------------------------------------------------------------------------- | ------------------------ | ------ | --------- |
| A1  | mason.nvim install + config                                                     | `plugins/editor/lsp.lua` | ⬜     | ⬜        |
| A2  | mason-lspconfig bridge                                                          | `plugins/editor/lsp.lua` | ⬜     | ⬜        |
| A3  | nvim-lspconfig (server data only)                                               | `plugins/editor/lsp.lua` | ⬜     | ⬜        |
| A4  | LspAttach autocmd (keymaps, capability-gated)                                   | `plugins/editor/lsp.lua` | ⬜     | ⬜        |
| A5  | vim.diagnostic.config()                                                         | `plugins/editor/lsp.lua` | ⬜     | ⬜        |
| A6  | lsp/lua_ls.lua native config                                                    | `lsp/lua_ls.lua`         | ⬜     | ⬜        |
| A7  | **CHECKPOINT**: lua_ls attaches, diagnostics render, hover works, no duplicates |                          | ⬜     | ⬜        |

**Validation A7:**

```
:checkhealth lsp                    → lua_ls active, YOUR settings loaded
:LspInfo (or :checkhealth lsp)      → exactly 1 client on .lua files
Open .lua, type bad code            → exactly 1 diagnostic per error
K on function                       → hover popup works
grn on variable                     → rename works
```

### Phase B — Completion (Lua-only validation)

| #   | Task                                                                                          | File                            | Status | Validated |
| --- | --------------------------------------------------------------------------------------------- | ------------------------------- | ------ | --------- |
| B1  | blink.cmp install + config                                                                    | `plugins/editor/completion.lua` | ⬜     | ⬜        |
| B2  | Manual trigger (NOT auto)                                                                     | `plugins/editor/completion.lua` | ⬜     | ⬜        |
| B3  | Sources: lsp + path + buffer                                                                  | `plugins/editor/completion.lua` | ⬜     | ⬜        |
| B4  | Snippets: OFF initially                                                                       | `plugins/editor/completion.lua` | ⬜     | ⬜        |
| B5  | Wire capabilities to LSP                                                                      | `plugins/editor/lsp.lua`        | ⬜     | ⬜        |
| B6  | **CHECKPOINT**: completion menu appears ONLY when summoned, correct items, no phantom entries |                                 | ⬜     | ⬜        |

**Validation B6:**

```
Type normally                       → NO menu appears (manual trigger only)
Press trigger key (C-Space or C-n)  → menu appears with LSP + buffer + path items
Select item                         → inserts correctly, no duplicates
:blink.cmp status (or equivalent)   → sources list matches config
```

### Phase C — Formatting (Lua-only validation)

| #   | Task                                                                                            | File                            | Status | Validated |
| --- | ----------------------------------------------------------------------------------------------- | ------------------------------- | ------ | --------- |
| C1  | conform.nvim install + config                                                                   | `plugins/editor/formatting.lua` | ⬜     | ⬜        |
| C2  | NO format-on-save (belt+suspenders)                                                             | `plugins/editor/formatting.lua` | ⬜     | ⬜        |
| C3  | Manual format: `<leader>cf`                                                                     | `plugins/editor/formatting.lua` | ⬜     | ⬜        |
| C4  | Disable LSP formatting caps                                                                     | `lsp/lua_ls.lua` or lsp.lua     | ⬜     | ⬜        |
| C5  | stylua for Lua (conform only, NOT LSP)                                                          | `plugins/editor/formatting.lua` | ⬜     | ⬜        |
| C6  | **CHECKPOINT**: save file → NO formatting happens. <leader>cf → stylua runs. No LSP formatting. |                                 | ⬜     | ⬜        |

**Validation C6:**

```
Mess up indentation, :w             → file saves AS-IS (no auto-format)
<leader>cf                          → stylua formats the buffer
:ConformInfo                        → shows stylua, NOT lsp_format
:LspInfo                            → lua_ls has NO formatting capability
stylua NOT in active LSP clients    → confirm no stylua LSP attachment
```

### Phase D — Linting (Lua-only validation)

| #   | Task                                                                             | File                      | Status | Validated |
| --- | -------------------------------------------------------------------------------- | ------------------------- | ------ | --------- |
| D1  | nvim-lint install + config                                                       | `plugins/editor/lint.lua` | ⬜     | ⬜        |
| D2  | Empty linters_by_ft (Lua = lua_ls covers it)                                     | `plugins/editor/lint.lua` | ⬜     | ⬜        |
| D3  | **CHECKPOINT**: no duplicate diagnostics on Lua files, nvim-lint loaded but idle |                           | ⬜     | ⬜        |

**Validation D3:**

```
Open .lua file with errors          → diagnostics come from lua_ls ONLY
:lua print(vim.inspect(require("lint").linters_by_ft)) → {} or no lua entry
No "double diagnostic" on any line
```

### Phase E — Lua Toolchain Sign-Off

| #   | Task                             | Status |
| --- | -------------------------------- | ------ |
| E1  | One-tool-per-job matrix verified | ⬜     |
| E2  | Startup time < 50ms              | ⬜     |
| E3  | :checkhealth all green           | ⬜     |
| E4  | Zero duplicate diagnostics       | ⬜     |
| E5  | Zero auto-format events          | ⬜     |

**Lua One-Tool-Per-Job Matrix (target state):**

| Concern        | Tool               | Count | Source          |
| -------------- | ------------------ | ----- | --------------- |
| Diagnostics    | lua_ls             | 1     | LSP             |
| Completion     | blink.cmp ← lua_ls | 1     | plugin + LSP    |
| Formatting     | stylua via conform | 1     | external binary |
| Hover/Goto/Ref | lua_ls             | 1     | LSP             |
| Rename         | lua_ls (grn)       | 1     | LSP             |
| Linting        | lua_ls (built-in)  | 1     | LSP             |
| Snippets       | OFF                | 0     | —               |

---

### Phase F — Language Expansion (AFTER Lua sign-off)

| #   | Language       | LSP Server              | Formatter            | Linter         | Status |
| --- | -------------- | ----------------------- | -------------------- | -------------- | ------ |
| F1  | TypeScript/JSX | ts_ls                   | prettierd → prettier | eslint (LSP?)  | ⬜     |
| F2  | Python         | basedpyright or pyright | ruff-format or black | ruff           | ⬜     |
| F3  | Java           | jdtls (nvim-jdtls)      | google-java-format   | jdtls built-in | ⬜     |
| F4  | JSON           | jsonls                  | prettierd            | jsonls         | ⬜     |
| F5  | YAML           | yamlls                  | prettierd            | yamlls         | ⬜     |
| F6  | HTML/CSS       | html + cssls            | prettierd            | LSP built-in   | ⬜     |
| F7  | SQL            | —                       | sql-formatter        | —              | ⬜     |
| F8  | Markdown       | —                       | prettierd            | markdownlint   | ⬜     |

Each language gets its own one-tool-per-job matrix validation before sign-off.

---

## Anti-Patterns Registry — Things That MUST NOT Happen

| #   | Anti-Pattern                                    | Prevention                                                                                    |
| --- | ----------------------------------------------- | --------------------------------------------------------------------------------------------- |
| 1   | Auto-format on save                             | No `format_on_save` in conform. No `BufWritePre` format autocmd. Disable LSP formatting caps. |
| 2   | Two tools doing same job on same filetype       | One-tool-per-job matrix per language. Verify with `:LspInfo` + `:ConformInfo`                 |
| 3   | stylua attaching as LSP                         | `automatic_enable = { exclude = { "stylua" } }` in mason-lspconfig                            |
| 4   | lsp/ directory in wrong location                | Must be at config root: `~/.config/nvim/lsp/`, NOT `lua/lsp/`                                 |
| 5   | Completion menu appearing without invocation    | `completion = { trigger = { show_on_insert_on_trigger_character = false } }` or equivalent    |
| 6   | nvim-lspconfig defaults overriding our settings | Verify with `:checkhealth lsp` — OUR settings must appear                                     |
| 7   | Orphaned plugin files at plugins/ root          | All specs in subdirectories only                                                              |
| 8   | Phantom servers from old Mason installs         | Audit `:Mason` after setup, uninstall unused                                                  |
| 9   | Duplicate diagnostics                           | Test: one error → exactly one diagnostic. If two appear, find the second source.              |
| 10  | Snippets interfering with completion            | Snippets OFF until explicitly enabled and validated                                           |

---

## Research Needed — Deep Dives Before Building

| #   | Topic                                                                                    | Priority | Status |
| --- | ---------------------------------------------------------------------------------------- | -------- | ------ |
| R1  | blink.cmp 2025/2026 state — manual trigger API, source config, snippet control           | 🔴       | ⬜     |
| R2  | mason.nvim + mason-lspconfig v2 current API — automatic_enable, exclude patterns         | 🔴       | ⬜     |
| R3  | nvim-lspconfig role in 0.11+ — what it provides vs native vim.lsp.config                 | 🔴       | ⬜     |
| R4  | conform.nvim — disable format-on-save completely, LSP formatting cap disabling           | 🔴       | ⬜     |
| R5  | vim.diagnostic.config() 0.11+ — virtual_lines, virtual_text, severity_sort               | 🟡       | ⬜     |
| R6  | nvim-lint current state — async behavior, diagnostic source attribution                  | 🟡       | ⬜     |
| R7  | ts_ls vs vtsls — current recommendation for TypeScript in 2026                           | 🟡       | ⬜     |
| R8  | basedpyright vs pyright vs ruff — Python LSP landscape 2026                              | 🟡       | ⬜     |
| R9  | nvim-jdtls — Java/Spring Boot setup, relationship with mason jdtls                       | 🟡       | ⬜     |
| R10 | Duplicate diagnostics root causes — eslint + ts_ls overlap, nvim-lint + LSP overlap      | 🔴       | ⬜     |
| R11 | nvim-java vs nvim-jdtls — Spring Boot support, dependency weight, debug/test integration | 🟡       | ⬜     |
| R12 | ftplugin/java.lua pattern vs plugins/lang/java.lua — community standard for jdtls boot   | 🟡       | ⬜     |

---

## Decisions Log

| Date       | Decision                                 | Rationale                                                   |
| ---------- | ---------------------------------------- | ----------------------------------------------------------- |
| 2026-02-10 | Lua-first validation before any language | Isolate issues at the simplest level                        |
| 2026-02-10 | Manual-trigger completion only           | Minimalist aesthetic, user preference                       |
| 2026-02-10 | NEVER auto-format                        | User's strongest preference. Previous config violated this. |
| 2026-02-10 | No snippets initially                    | Add control before adding complexity                        |
| 2026-02-10 | No AI completion (Copilot deferred)      | Clean foundation first, inject later                        |
| 2026-02-10 | One-tool-per-job matrix per language     | Prevents duplicate diagnostics and formatting wars          |

---

_IDEI Build Tracker — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
