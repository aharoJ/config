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
- **Multi-LLM research**: Every Phase F language expansion uses 5-6 LLMs competing, best findings merged

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

### Phase A — LSP Foundation (Lua-only validation) ✅

| #   | Task                                                                            | File                     | Status | Validated |
| --- | ------------------------------------------------------------------------------- | ------------------------ | ------ | --------- |
| A1  | mason.nvim install + config                                                     | `plugins/editor/lsp.lua` | ✅     | ✅        |
| A2  | mason-lspconfig bridge                                                          | `plugins/editor/lsp.lua` | ✅     | ✅        |
| A3  | nvim-lspconfig (server data only)                                               | `plugins/editor/lsp.lua` | ✅     | ✅        |
| A4  | LspAttach autocmd (keymaps, capability-gated)                                   | `plugins/editor/lsp.lua` | ✅     | ✅        |
| A5  | vim.diagnostic.config()                                                         | `plugins/editor/lsp.lua` | ✅     | ✅        |
| A6  | lsp/lua_ls.lua native config                                                    | `lsp/lua_ls.lua`         | ✅     | ✅        |
| A7  | **CHECKPOINT**: lua_ls attaches, diagnostics render, hover works, no duplicates |                          | ✅     | ✅        |

### Phase B — Completion (Lua-only validation) ✅

| #   | Task                                                                                          | File                            | Status | Validated |
| --- | --------------------------------------------------------------------------------------------- | ------------------------------- | ------ | --------- |
| B1  | blink.cmp install + config                                                                    | `plugins/editor/completion.lua` | ✅     | ✅        |
| B2  | Manual trigger (NOT auto)                                                                     | `plugins/editor/completion.lua` | ✅     | ✅        |
| B3  | Sources: lsp + path + buffer                                                                  | `plugins/editor/completion.lua` | ✅     | ✅        |
| B4  | Snippets: OFF initially                                                                       | `plugins/editor/completion.lua` | ✅     | ✅        |
| B5  | Wire capabilities to LSP                                                                      | `plugins/editor/lsp.lua`        | ✅     | ✅        |
| B6  | **CHECKPOINT**: completion menu appears ONLY when summoned, correct items, no phantom entries |                                 | ✅     | ✅        |

### Phase C — Formatting (Lua-only validation) ✅

| #   | Task                                                                                            | File                            | Status | Validated |
| --- | ----------------------------------------------------------------------------------------------- | ------------------------------- | ------ | --------- |
| C1  | conform.nvim install + config                                                                   | `plugins/editor/formatting.lua` | ✅     | ✅        |
| C2  | NO format-on-save (belt+suspenders)                                                             | `plugins/editor/formatting.lua` | ✅     | ✅        |
| C3  | Manual format: `<leader>cf`                                                                     | `plugins/editor/formatting.lua` | ✅     | ✅        |
| C4  | Disable LSP formatting caps                                                                     | `plugins/editor/lsp.lua`        | ✅     | ✅        |
| C5  | stylua for Lua (conform only, NOT LSP)                                                          | `plugins/editor/formatting.lua` | ✅     | ✅        |
| C6  | **CHECKPOINT**: save file → NO formatting happens. <leader>cf → stylua runs. No LSP formatting. |                                 | ✅     | ✅        |

**Validation C6:**

```
Mess up indentation, :w             → file saves AS-IS (no auto-format)     ✅
<leader>cf                          → stylua formats the buffer             ✅
:ConformInfo                        → shows stylua, NOT lsp_format          ✅
:LspInfo                            → lua_ls has NO formatting capability   ✅
stylua NOT in active LSP clients    → confirm no stylua LSP attachment      ✅
```

### Phase D — Linting (Lua-only validation) ✅

| #   | Task                                                                             | File                      | Status | Validated |
| --- | -------------------------------------------------------------------------------- | ------------------------- | ------ | --------- |
| D1  | nvim-lint install + config                                                       | `plugins/editor/lint.lua` | ✅     | ✅        |
| D2  | Empty linters_by_ft (Lua = lua_ls covers it)                                     | `plugins/editor/lint.lua` | ✅     | ✅        |
| D3  | **CHECKPOINT**: no duplicate diagnostics on Lua files, nvim-lint loaded but idle |                           | ✅     | ✅        |

**Validation D3:**

```
Open .lua file with errors          → diagnostics come from lua_ls ONLY     ✅
:lua print(vim.inspect(require("lint").linters_by_ft)) → {}                 ✅
No "double diagnostic" on any line                                          ✅
nvim-lint loaded but idle — infrastructure for Phase F                      ✅
```

### Phase E — Lua Toolchain Sign-Off ✅

| #   | Task                             | Status |
| --- | -------------------------------- | ------ |
| E1  | One-tool-per-job matrix verified | ✅     |
| E2  | Startup time < 50ms              | ✅     |
| E3  | :checkhealth all green           | ✅     |
| E4  | Zero duplicate diagnostics       | ✅     |
| E5  | Zero auto-format events          | ✅     |

**Lua One-Tool-Per-Job Matrix (verified):**

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

### Phase F — Language Expansion ✅ (TypeScript/Tailwind) | 🔵 (remaining)

| #   | Language       | LSP Server                   | Formatter            | Linter         | Status |
| --- | -------------- | ---------------------------- | -------------------- | -------------- | ------ |
| F1  | TypeScript/JSX | ts_ls + eslint + tailwindcss | prettierd → prettier | eslint (LSP)   | ✅     |
| F2  | Python         | basedpyright or pyright      | ruff-format or black | ruff           | ⬜     |
| F3  | Java           | jdtls (nvim-jdtls)           | google-java-format   | jdtls built-in | ⬜     |
| F4  | SQL            | —                            | sql-formatter        | —              | ⬜     |
| F5  | Markdown       | —                            | prettierd            | markdownlint   | ⬜     |

**NOTE:** JSON, YAML, HTML, CSS formatting is handled by prettierd (Phase F1). No dedicated LSP
servers needed — ts_ls provides type checking for JSON imports, and Tailwind CSS LSP handles
CSS class intellisense. Separate jsonls/yamlls/html/cssls servers deferred unless explicit need arises.

**TypeScript/Tailwind One-Tool-Per-Job Matrix (verified):**

| Concern                 | Tool                    | Count | Source          |
| ----------------------- | ----------------------- | ----- | --------------- |
| Diagnostics (types)     | ts_ls                   | 1     | LSP             |
| Diagnostics (lint)      | eslint                  | 1     | LSP             |
| Diagnostics (classes)   | tailwindcss             | 1     | LSP             |
| Completion (TS/JS)      | blink.cmp ← ts_ls       | 1     | plugin + LSP    |
| Completion (Tailwind)   | blink.cmp ← tailwindcss | 1     | plugin + LSP    |
| Formatting              | prettierd via conform   | 1     | external binary |
| Hover/Goto/Ref          | ts_ls                   | 1     | LSP             |
| Hover (Tailwind CSS)    | tailwindcss             | 1     | LSP             |
| Rename                  | ts_ls                   | 1     | LSP             |
| Code Actions (refactor) | ts_ls                   | 1     | LSP             |
| Code Actions (lint fix) | eslint                  | 1     | LSP             |
| Snippets                | OFF                     | 0     | —               |

Three LSP servers, zero overlap. ts_ls owns type system, eslint owns lint rules, tailwindcss owns utility class intelligence.

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
| 11  | Formatters installed via mason-lspconfig        | Formatters use `:MasonInstall` directly. mason-lspconfig is for LSP servers ONLY.             |
| 12  | Eager-loading formatting plugin                 | No `event` trigger on conform. Load only on `keys` + `cmd`.                                   |
| 13  | ESLint via nvim-lint (duplicate diagnostics)    | ESLint runs as LSP, not through nvim-lint. nvim-lint uses separate diagnostic namespace.      |
| 14  | ts_ls + eslint unused-var overlap               | `ignoredCodes = { 6133, 6196 }` in ts_ls suppresses TS unused-var checks.                     |
| 15  | Tailwind completions only in className=""       | `experimental.classRegex` patterns for clsx/cn/cva/tw``.                                      |

---

## Research Needed — Deep Dives Before Building

| #   | Topic                                                                                    | Priority | Status |
| --- | ---------------------------------------------------------------------------------------- | -------- | ------ |
| R1  | blink.cmp 2025/2026 state — manual trigger API, source config, snippet control           | 🔴       | ✅     |
| R2  | mason.nvim + mason-lspconfig v2 current API — automatic_enable, exclude patterns         | 🔴       | ✅     |
| R3  | nvim-lspconfig role in 0.11+ — what it provides vs native vim.lsp.config                 | 🔴       | ✅     |
| R4  | conform.nvim — disable format-on-save completely, LSP formatting cap disabling           | 🔴       | ✅     |
| R5  | vim.diagnostic.config() 0.11+ — virtual_lines, virtual_text, severity_sort               | 🟡       | ✅     |
| R6  | nvim-lint current state — async behavior, diagnostic source attribution                  | 🟡       | ✅     |
| R7  | ts_ls vs vtsls — current recommendation for TypeScript in 2026                           | 🟡       | ✅     |
| R8  | basedpyright vs pyright vs ruff — Python LSP landscape 2026                              | 🟡       | ⬜     |
| R9  | nvim-jdtls — Java/Spring Boot setup, relationship with mason jdtls                       | 🟡       | ⬜     |
| R10 | Duplicate diagnostics: ts_ls ignoredCodes {6133, 6196} prevents eslint overlap           | 🔴       | ✅     |
| R11 | Root detection: explicit root_markers for monorepo support (ts_ls, eslint, tailwindcss)  | 🔴       | ✅     |
| R12 | Monorepo safety: eslint workingDirectories.mode = "auto" (4.8→4.10 bug avoidance)        | 🔴       | ✅     |
| R13 | ESLint as LSP vs nvim-lint: nvim-lint#826 separate namespace = visual clutter            | 🔴       | ✅     |
| R14 | Import preferences: preferTypeOnlyAutoImports, omit importModuleSpecifier for aliases    | 🟡       | ✅     |
| R15 | Tailwind classRegex: enable intellisense in clsx/cn/cva/tw`` utility functions           | 🟡       | ✅     |
| R16 | nvim-java vs nvim-jdtls — Spring Boot support, dependency weight, debug/test integration | 🟡       | ⬜     |
| R17 | ftplugin/java.lua pattern vs plugins/lang/java.lua — community standard for jdtls boot   | 🟡       | ⬜     |

---

## Decisions Log

| Date       | Decision                                      | Rationale                                                                                  |
| ---------- | --------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 2026-02-10 | Lua-first validation before any language      | Isolate issues at the simplest level                                                       |
| 2026-02-10 | Manual-trigger completion only                | Minimalist aesthetic, user preference                                                      |
| 2026-02-10 | NEVER auto-format                             | User's strongest preference. Previous config violated this.                                |
| 2026-02-10 | No snippets initially                         | Add control before adding complexity                                                       |
| 2026-02-10 | No AI completion (Copilot deferred)           | Clean foundation first, inject later                                                       |
| 2026-02-10 | One-tool-per-job matrix per language          | Prevents duplicate diagnostics and formatting wars                                         |
| 2026-02-11 | blink.cmp auto-wires capabilities on 0.11+    | No manual `get_lsp_capabilities()`. Saghen confirmed in Discussion #1802.                  |
| 2026-02-11 | `workspace.library = { vim.env.VIMRUNTIME }`  | Manual alternative to lazydev.nvim. One line, no plugin dependency.                        |
| 2026-02-11 | Formatters via `:MasonInstall`, not lspconfig | Formatters are NOT LSP servers. Root cause of old stylua-as-LSP bug.                       |
| 2026-02-11 | No `format_on_save` key — absent, not `false` | Explicit omission. Conform never hooks BufWritePre.                                        |
| 2026-02-11 | No `prepend_args` for stylua                  | Let stylua read `.stylua.toml` from project root. CLI args override project config.        |
| 2026-02-11 | Lazy-load conform on `keys` + `cmd` only      | No `event` trigger. Zero startup cost. 3/4 feedback LLMs got this wrong.                   |
| 2026-02-11 | nvim-lint idle for Lua (Phase D)              | lua_ls covers all Lua diagnostics. nvim-lint is infrastructure for Phase F.                |
| 2026-02-11 | ESLint as LSP, not nvim-lint                  | nvim-lint#826: separate diagnostic namespace = visual clutter. LSP gives code actions too. |
| 2026-02-11 | ts_ls ignoredCodes {6133, 6196}               | Prevents duplicate unused-var diagnostics (ts_ls + eslint overlap).                        |
| 2026-02-11 | Explicit root_markers on all LSP servers      | Monorepo safety. Default root detection can attach at wrong level.                         |
| 2026-02-11 | eslint workingDirectories.mode = "auto"       | Auto-detect CWD from config location. Avoids 4.8→4.10 silent failure bug.                  |
| 2026-02-11 | tailwindcss as third LSP client               | Zero overlap: ts_ls=types, eslint=lint, tailwindcss=class intelligence.                    |
| 2026-02-11 | Tailwind classRegex for clsx/cn/cva/tw``      | Without regex, completions only work in className="". Misses shadcn/ui cn() pattern.       |
| 2026-02-11 | preferTypeOnlyAutoImports = true              | Cleaner tree-shaking. Standard for modern React/Next.js.                                   |
| 2026-02-11 | Omit importModuleSpecifierPreference          | Default "shortest" respects tsconfig paths aliases. "relative" fights Next.js aliases.     |
| 2026-02-11 | prettierd with prettier fallback              | Daemon wrapper (~10x faster). Falls back to prettier if prettierd not installed.           |
| 2026-02-11 | Multi-LLM competitive research for Phase F    | 6 LLMs (GPT, Kimi, DeepSeek, Gemini, Claude A, Claude B) — best findings merged.           |
| 2026-02-11 | No dedicated jsonls/yamlls/html/cssls         | prettierd handles formatting. No need for separate LSPs unless explicit need arises.       |

---

_IDEI Build Tracker — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
