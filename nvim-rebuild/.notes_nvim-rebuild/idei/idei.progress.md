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
│  sources: lsp,       │  virtual_text   │  external      │
│    path, buffer      │  (current_line) │  formatters    │
├──────────────────────┤  signs + under- ├────────────────┤
│  SNIPPETS            │  line (always)  │  LINTING       │
│  vim.snippet (native)│                 │  nvim-lint     │
│  (Phase 2 — off      │                 │  (sparse —     │
│   initially)         │                 │   LSP covers   │
│                      │                 │   most)        │
├──────────────────────┴─────────────────┴────────────────┤
│                    LSP LAYER                            │
│  vim.lsp.config() + vim.lsp.enable()  (native 0.11+)   │
│  lsp/<server>.lua    (file-based auto-discovery)        │
│  nvim-lspconfig      (bundled server configs only)      │
│  nvim-jdtls          (ftplugin pattern for Java)        │
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

### Phase D — Linting (Lua-only validation) ✅

| #   | Task                                                                             | File                      | Status | Validated |
| --- | -------------------------------------------------------------------------------- | ------------------------- | ------ | --------- |
| D1  | nvim-lint install + config                                                       | `plugins/editor/lint.lua` | ✅     | ✅        |
| D2  | Empty linters_by_ft (Lua = lua_ls covers it)                                     | `plugins/editor/lint.lua` | ✅     | ✅        |
| D3  | **CHECKPOINT**: no duplicate diagnostics on Lua files, nvim-lint loaded but idle |                           | ✅     | ✅        |

### Phase E — Lua Toolchain Sign-Off ✅

| #   | Task                             | Status |
| --- | -------------------------------- | ------ |
| E1  | One-tool-per-job matrix verified | ✅     |
| E2  | Startup time < 50ms              | ✅     |
| E3  | :checkhealth all green           | ✅     |
| E4  | Zero duplicate diagnostics       | ✅     |
| E5  | Zero auto-format events          | ✅     |

---

### Phase F — Language Expansion

| #   | Language       | LSP Server                   | Formatter                    | Linter                  | Status |
| --- | -------------- | ---------------------------- | ---------------------------- | ----------------------- | ------ |
| F1  | TypeScript/JSX | ts_ls + eslint + tailwindcss | prettierd → prettier         | eslint (LSP)            | ✅     |
| F2  | Java           | jdtls (nvim-jdtls ftplugin)  | google-java-format (2-space) | jdtls built-in          | ✅     |
| F3  | Python         | basedpyright                 | ruff eliminated removed      | basedpyright (built-in) | ✅     |
| F4  | Rust           | rust_analyzer                | rustfmt via conform          | clippy (via RA)         | ⬜     |
| F5  | SQL            | —                            | sql-formatter                | —                       | ✅     |
| F6  | Markdown       | marksman                     | prettierd                    | markdownlint-cli2       | ⬜     |
| F7  | XML            | lemminx                      | lemminx (LSP)                | lemminx (LSP)           | ✅     |
| F8  | YAML           | yamlls + SchemaStore.nvim    | prettierd                    | yamlls (LSP)            | ✅     |
| F9  | TOML           | taplo                        | taplo via conform            | taplo (LSP)             | ✅     |
| F11 | Bash           | bashls                       | shfmt via conform            | shellcheck (via bashls) | ✅     |
| F10 | Fish           | fish_lsp                     | fish_indent via conform      | fish_lsp (LSP)          | ✅     |
| F12 | JSON           | jsonls + SchemaStore.nvim    | prettierd                    | jsonls (LSP)            | ✅     |

**NOTE:** HTML/CSS LSP servers remain deferred — prettierd handles formatting, tailwindcss handles
class intellisense. Separate html/cssls servers only if explicit need arises.

**Formatter Consolidation:** prettierd handles 5 filetypes (TypeScript, JSON, YAML, Markdown, HTML/CSS).
Daemon wrapper (~10x faster than prettier). Falls back to prettier if prettierd not installed.

**Plugin:** SchemaStore.nvim — provides 400+ schemas for jsonls and yamlls
(package.json, tsconfig.json, application.yml, docker-compose, GitHub Actions, K8s manifests).

---

### Phase F — One-Tool-Per-Job Matrices

**TypeScript/Tailwind (F1 — verified):**

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

**Java (F2 — verified):**

| Concern                 | Tool                           | Count | Source          |
| ----------------------- | ------------------------------ | ----- | --------------- |
| Diagnostics             | jdtls                          | 1     | LSP             |
| Completion              | blink.cmp ← jdtls              | 1     | plugin + LSP    |
| Formatting              | google-java-format via conform | 1     | external binary |
| Hover/Goto/Ref          | jdtls                          | 1     | LSP             |
| Rename                  | jdtls                          | 1     | LSP             |
| Code Actions (refactor) | jdtls + nvim-jdtls             | 1     | LSP + plugin    |
| Linting                 | jdtls (built-in)               | 1     | LSP             |
| Snippets                | OFF                            | 0     | —               |

**Python (F3 — verified):**

| Concern             | Tool                     | Count | Source          |
| ------------------- | ------------------------ | ----- | --------------- |
| Diagnostics (types) | basedpyright             | 1     | LSP             |
| Diagnostics (lint)  | basedpyright             | 1     | LSP             |
| Completion          | blink.cmp ← basedpyright | 1     | plugin + LSP    |
| Formatting          | ruff_format via conform  | 1     | external binary |
| Hover/Goto/Ref      | basedpyright             | 1     | LSP             |
| Rename              | basedpyright             | 1     | LSP             |
| Code Actions        | basedpyright             | 1     | LSP             |
| Snippets            | OFF                      | 0     | —               |

**Key:** basedpyright is the SOLE Python LSP. ruff was initially paired as linting LSP but DROPPED
due to systemic diagnostic overlap — unused vars (F841↔reportUnusedVariable), undefined names
(F821↔reportUndefinedVariable), statement separation (E702↔parser errors), invalid string escapes
(W605↔reportInvalidStringEscapeSequence). Community has been playing whack-a-mole with suppressions
for 1+ year (basedpyright#203, ruff-lsp#384, LazyVim#5818). Parser-level conflicts (E702) are
unsolvable through config. basedpyright `"standard"` mode catches real bugs. ruff_format KEPT via
conform (CLI formatter, no LSP needed). One server, zero duplicates, zero maintenance.

**Rust (F4 — researched, pending implementation):**

| Concern      | Tool            | Count | Source          |
| ------------ | --------------- | ----- | --------------- |
| Diagnostics  | rust-analyzer   | 1     | LSP             |
| Completion   | blink.cmp ← RA  | 1     | plugin + LSP    |
| Formatting   | rustfmt         | 1     | conform (CLI)   |
| Hover/Goto   | rust-analyzer   | 1     | LSP             |
| Rename       | rust-analyzer   | 1     | LSP             |
| Code Actions | rust-analyzer   | 1     | LSP             |
| Linting      | clippy (via RA) | 1     | LSP diagnostics |
| Snippets     | OFF             | 0     | —               |

**Key:** Single-server language. `check.command = "clippy"` in RA settings runs clippy instead of
plain `cargo check`, providing lint-level diagnostics alongside type errors. `procMacro.enable = true`
for accurate analysis. rustaceanvim is the upgrade path if deeper Rust tooling needed later — it
manages its own LSP client and CONFLICTS with native `lsp/rust_analyzer.lua` (pick one approach).

**Markdown (F6 — researched, pending implementation):**

| Concern     | Tool                  | Count | Source          |
| ----------- | --------------------- | ----- | --------------- |
| Diagnostics | markdownlint-cli2     | 1     | nvim-lint       |
| Completion  | blink.cmp ← marksman  | 1     | plugin + LSP    |
| Formatting  | prettierd via conform | 1     | external binary |
| Hover/Goto  | marksman              | 1     | LSP             |
| Snippets    | OFF                   | 0     | —               |

**Key:** marksman provides wiki-links, cross-references, document symbols (Zettelkasten support).
markdownlint-cli2 via nvim-lint (the only nvim-lint entry beyond Lua baseline).

**XML (F7 — verified):**

| Concern      | Tool    | Count | Source |
| ------------ | ------- | ----- | ------ |
| Diagnostics  | lemminx | 1     | LSP    |
| Completion   | lemminx | 1     | LSP    |
| Formatting   | lemminx | 1     | LSP    |
| Hover/Goto   | lemminx | 1     | LSP    |
| Code Actions | lemminx | 1     | LSP    |

**Key:** lemminx handles ALL concerns — formatting, validation, completion. Schema-aware for Maven
POM, Spring configs. Config: `workDir = ~/.cache/lemminx` for XDG compliance. Exception to
"no LSP formatting" rule — lemminx is the ONLY formatter for XML, no external CLI alternative.

**YAML (F8 — verified):**

| Concern     | Tool                  | Count | Source          |
| ----------- | --------------------- | ----- | --------------- |
| Diagnostics | yamlls                | 1     | LSP             |
| Completion  | blink.cmp ← yamlls    | 1     | plugin + LSP    |
| Formatting  | prettierd via conform | 1     | external binary |
| Hover       | yamlls                | 1     | LSP             |

**Key:** SchemaStore.nvim provides 400+ schemas (application.yml, docker-compose, GitHub Actions, K8s).
MUST disable yamlls built-in schemaStore: `schemaStore = { enable = false, url = "" }` when using
SchemaStore.nvim plugin (prevents duplicate schema loading).

**TOML (F9 — verified):**

| Concern     | Tool              | Count | Source        |
| ----------- | ----------------- | ----- | ------------- |
| Diagnostics | taplo             | 1     | LSP           |
| Completion  | blink.cmp ← taplo | 1     | plugin + LSP  |
| Formatting  | taplo via conform | 1     | conform (CLI) |
| Hover       | taplo             | 1     | LSP           |

**Key:** taplo handles Cargo.toml, pyproject.toml, etc. Built-in formatting + validation + schema
support. Formatting via conform (not LSP — manual-only pattern).

**Fish (F10 — verified):**

| Concern     | Tool                 | Count | Source        |
| ----------- | -------------------- | ----- | ------------- |
| Diagnostics | fish_lsp             | 1     | LSP           |
| Completion  | blink.cmp ← fish_lsp | 1     | plugin + LSP  |
| Formatting  | fish_indent          | 1     | conform (CLI) |

**Key:** fish_lsp available in nvim-lspconfig, installable via brew/npm. fish_indent ships with
fish shell (built-in formatter).

**Bash (F11 — verified):**

| Concern     | Tool                  | Count | Source          |
| ----------- | --------------------- | ----- | --------------- |
| Diagnostics | bashls (+ shellcheck) | 1     | LSP             |
| Completion  | blink.cmp ← bashls    | 1     | plugin + LSP    |
| Formatting  | shfmt via conform     | 1     | external binary |
| Hover       | bashls                | 1     | LSP             |

**CRITICAL:** bashls auto-integrates shellcheck (500ms debounce). DO NOT add shellcheck to nvim-lint
— this causes duplicate diagnostics.

**JSON (F12 — verified):**

| Concern     | Tool                  | Count | Source          |
| ----------- | --------------------- | ----- | --------------- |
| Diagnostics | jsonls                | 1     | LSP             |
| Completion  | blink.cmp ← jsonls    | 1     | plugin + LSP    |
| Formatting  | prettierd via conform | 1     | external binary |
| Hover       | jsonls                | 1     | LSP             |

**Key:** SchemaStore.nvim provides 400+ schemas (package.json, tsconfig.json, .eslintrc).
MUST set `validate = { enable = true }` explicitly — upstream bug defaults to false.

---

## Anti-Patterns Registry — Things That MUST NOT Happen

| #   | Anti-Pattern                                       | Prevention                                                                                         |
| --- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| 1   | Auto-format on save                                | No `format_on_save` in conform. No `BufWritePre` format autocmd. Disable LSP formatting caps.      |
| 2   | Two tools doing same job on same filetype          | One-tool-per-job matrix per language. Verify with `:LspInfo` + `:ConformInfo`                      |
| 3   | stylua attaching as LSP                            | `automatic_enable = { exclude = { "stylua" } }` in mason-lspconfig                                 |
| 4   | lsp/ directory in wrong location                   | Must be at config root: `~/.config/nvim/lsp/`, NOT `lua/lsp/`                                      |
| 5   | Completion menu appearing without invocation       | `completion = { trigger = { show_on_insert_on_trigger_character = false } }` or equivalent         |
| 6   | nvim-lspconfig defaults overriding our settings    | Verify with `:checkhealth lsp` — OUR settings must appear                                          |
| 7   | Orphaned plugin files at plugins/ root             | All specs in subdirectories only                                                                   |
| 8   | Phantom servers from old Mason installs            | Audit `:Mason` after setup, uninstall unused                                                       |
| 9   | Duplicate diagnostics                              | Test: one error → exactly one diagnostic. If two appear, find the second source.                   |
| 10  | Snippets interfering with completion               | Snippets OFF until explicitly enabled and validated                                                |
| 11  | Formatters installed via mason-lspconfig           | Formatters use `:MasonInstall` directly. mason-lspconfig is for LSP servers ONLY.                  |
| 12  | Eager-loading formatting plugin                    | No `event` trigger on conform. Load only on `keys` + `cmd`.                                        |
| 13  | ESLint via nvim-lint (duplicate diagnostics)       | ESLint runs as LSP, not through nvim-lint. nvim-lint uses separate diagnostic namespace.           |
| 14  | ts_ls + eslint unused-var overlap                  | `ignoredCodes = { 6133, 6196 }` in ts_ls suppresses TS unused-var checks.                          |
| 15  | Tailwind completions only in className=""          | `experimental.classRegex` patterns for clsx/cn/cva/tw``.                                           |
| 16  | jdtls dual-attachment (mason-lspconfig + ftplugin) | `automatic_enable = { exclude = { "jdtls" } }`. nvim-jdtls owns startup via ftplugin.              |
| 17  | jdtls workspace cross-pollution                    | Per-project workspace dir: `~/.cache/nvim/jdtls/<project_name>/workspace`                          |
| 18  | shellcheck via nvim-lint + bashls                  | bashls integrates shellcheck automatically. DO NOT add to nvim-lint.                               |
| 19  | basedpyright + ruff diagnostic overlap             | ruff LSP DROPPED. basedpyright is sole Python LSP. Overlap unsolvable (parser errors, F821, E702). |
| 20  | yamlls built-in schemaStore + SchemaStore.nvim     | Disable built-in: `schemaStore = { enable = false, url = "" }` when using SchemaStore.nvim.        |
| 21  | jsonls validation silently disabled                | Always set `validate = { enable = true }` explicitly. Upstream bug defaults to false.              |
| 22  | ruff-lsp (deprecated) or ruff as LSP               | ruff LSP dropped entirely for Python. ruff_format via conform only.                                |
| 23  | rustaceanvim + native lsp/rust_analyzer.lua        | rustaceanvim manages its own LSP client. Pick ONE approach. Start native, upgrade if needed.       |
| 24  | rust-tools.nvim (archived Jan 2024)                | Successor is rustaceanvim. Do not install rust-tools.nvim.                                         |
| 25  | rustfmt via LSP formatting instead of conform      | Route through conform for manual-only trigger. Disable RA documentFormattingProvider if needed.    |

---

## Diagnostic Display Configuration

```lua
virtual_text = true,    -- Inline diagnostics after the line (always visible)
virtual_lines = false,  -- NO multi-line block below code (too noisy)
signs = true,           -- Gutter icons (Error/Warn/Info/Hint)
underline = true,       -- Squiggly underline on affected code spans
```

**Decision:** `virtual_lines` was tested with `{ current_line = true }` — too intrusive, pushes buffer
down when cursor lands on diagnostic lines. `virtual_text = true` with signs + underlines provides
the right balance: you see WHERE problems are (gutter signs), WHAT's wrong (inline text), and the
exact code affected (underline). No vertical layout shift.

---

## Implementation Checklist — Phase F Remaining (F4–F6)

**LSP configs to create (`lsp/<server>.lua`):**

- [ ] `lsp/rust_analyzer.lua` — Rust (check.command = "clippy", procMacro.enable = true)
- [ ] `lsp/marksman.lua` — Markdown cross-references

**Conform formatters to add:**

- [ ] `rustfmt` — Rust
- [ ] `sql-formatter` — SQL

**nvim-lint linters to add:**

- [ ] `markdownlint-cli2` — Markdown (ONLY new nvim-lint entry; all others via LSP)

**Validation per language:**

- [ ] One-tool-per-job matrix verified (no duplicate diagnostics)
- [ ] `:LspInfo` shows expected servers only
- [ ] `:ConformInfo` shows expected formatter only
- [ ] Manual format `<leader>cf` works, no auto-format on save

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
| R8  | basedpyright + ruff — Python LSP landscape 2026                                          | 🟡       | ✅     |
| R9  | nvim-jdtls — Java/Spring Boot setup, relationship with mason jdtls                       | 🟡       | ✅     |
| R10 | Duplicate diagnostics: ts_ls ignoredCodes {6133, 6196} prevents eslint overlap           | 🔴       | ✅     |
| R11 | Root detection: explicit root_markers for monorepo support (ts_ls, eslint, tailwindcss)  | 🔴       | ✅     |
| R12 | Monorepo safety: eslint workingDirectories.mode = "auto" (4.8→4.10 bug avoidance)        | 🔴       | ✅     |
| R13 | ESLint as LSP vs nvim-lint: nvim-lint#826 separate namespace = visual clutter            | 🔴       | ✅     |
| R14 | Import preferences: preferTypeOnlyAutoImports, omit importModuleSpecifier for aliases    | 🟡       | ✅     |
| R15 | Tailwind classRegex: enable intellisense in clsx/cn/cva/tw`` utility functions           | 🟡       | ✅     |
| R16 | nvim-java vs nvim-jdtls — Spring Boot support, dependency weight, debug/test integration | 🟡       | ✅     |
| R17 | ftplugin/java.lua pattern vs plugins/lang/java.lua — community standard for jdtls boot   | 🟡       | ✅     |
| R18 | jdtls dual-attachment — mason-lspconfig automatic_enable.exclude prevents conflict       | 🔴       | ✅     |
| R19 | rust-analyzer vs rustaceanvim — tradeoffs for non-primary Rust usage                     | 🟡       | ✅     |
| R20 | SchemaStore.nvim — jsonls/yamlls schema integration, disable built-in schemaStore        | 🟡       | ✅     |
| R21 | lemminx — XML LSP for Maven POM/Spring config, XDG workDir config                        | 🟡       | ✅     |
| R22 | bashls shellcheck integration — auto-integrated, avoid nvim-lint duplication             | 🟡       | ✅     |
| R23 | fish_lsp — availability in nvim-lspconfig, install methods                               | 🟡       | ✅     |
| R24 | taplo — TOML LSP with built-in formatting, Cargo.toml/pyproject.toml support             | 🟡       | ✅     |
| R25 | basedpyright + ruff overlap — systemic duplicate diagnostics, community whack-a-mole     | 🔴       | ✅     |

---

## Decisions Log

| Date       | Decision                                        | Rationale                                                                                                                                                                                                         |
| ---------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-02-10 | Lua-first validation before any language        | Isolate issues at the simplest level                                                                                                                                                                              |
| 2026-02-10 | Manual-trigger completion only                  | Minimalist aesthetic, user preference                                                                                                                                                                             |
| 2026-02-10 | NEVER auto-format                               | User's strongest preference. Previous config violated this.                                                                                                                                                       |
| 2026-02-10 | No snippets initially                           | Add control before adding complexity                                                                                                                                                                              |
| 2026-02-10 | No AI completion (Copilot deferred)             | Clean foundation first, inject later                                                                                                                                                                              |
| 2026-02-10 | One-tool-per-job matrix per language            | Prevents duplicate diagnostics and formatting wars                                                                                                                                                                |
| 2026-02-11 | blink.cmp auto-wires capabilities on 0.11+      | No manual `get_lsp_capabilities()`. Saghen confirmed in Discussion #1802.                                                                                                                                         |
| 2026-02-11 | `workspace.library = { vim.env.VIMRUNTIME }`    | Manual alternative to lazydev.nvim. One line, no plugin dependency.                                                                                                                                               |
| 2026-02-11 | Formatters via `:MasonInstall`, not lspconfig   | Formatters are NOT LSP servers. Root cause of old stylua-as-LSP bug.                                                                                                                                              |
| 2026-02-11 | No `format_on_save` key — absent, not `false`   | Explicit omission. Conform never hooks BufWritePre.                                                                                                                                                               |
| 2026-02-11 | No `prepend_args` for stylua                    | Let stylua read `.stylua.toml` from project root. CLI args override project config.                                                                                                                               |
| 2026-02-11 | Lazy-load conform on `keys` + `cmd` only        | No `event` trigger. Zero startup cost. 3/4 feedback LLMs got this wrong.                                                                                                                                          |
| 2026-02-11 | nvim-lint idle for Lua (Phase D)                | lua_ls covers all Lua diagnostics. nvim-lint is infrastructure for Phase F.                                                                                                                                       |
| 2026-02-11 | ESLint as LSP, not nvim-lint                    | nvim-lint#826: separate diagnostic namespace = visual clutter. LSP gives code actions too.                                                                                                                        |
| 2026-02-11 | ts_ls ignoredCodes {6133, 6196}                 | Prevents duplicate unused-var diagnostics (ts_ls + eslint overlap).                                                                                                                                               |
| 2026-02-11 | Explicit root_markers on all LSP servers        | Monorepo safety. Default root detection can attach at wrong level.                                                                                                                                                |
| 2026-02-11 | eslint workingDirectories.mode = "auto"         | Auto-detect CWD from config location. Avoids 4.8→4.10 silent failure bug.                                                                                                                                         |
| 2026-02-11 | tailwindcss as third LSP client                 | Zero overlap: ts_ls=types, eslint=lint, tailwindcss=class intelligence.                                                                                                                                           |
| 2026-02-11 | Tailwind classRegex for clsx/cn/cva/tw``        | Without regex, completions only work in className="". Misses shadcn/ui cn() pattern.                                                                                                                              |
| 2026-02-11 | preferTypeOnlyAutoImports = true                | Cleaner tree-shaking. Standard for modern React/Next.js.                                                                                                                                                          |
| 2026-02-11 | Omit importModuleSpecifierPreference            | Default "shortest" respects tsconfig paths aliases. "relative" fights Next.js aliases.                                                                                                                            |
| 2026-02-11 | prettierd with prettier fallback                | Daemon wrapper (~10x faster). Falls back to prettier if prettierd not installed.                                                                                                                                  |
| 2026-02-11 | Multi-LLM competitive research for Phase F      | 6 LLMs (GPT, Kimi, DeepSeek, Gemini, Claude A, Claude B) — best findings merged.                                                                                                                                  |
| 2026-02-11 | nvim-jdtls over nvim-java for Java              | KISS, explicit, no nui.nvim bloat, no custom Mason registry. Community standard.                                                                                                                                  |
| 2026-02-11 | ftplugin/java.lua pattern for jdtls             | jdtls needs per-project config (workspace dirs, bundles). ftplugin is standard mechanism.                                                                                                                         |
| 2026-02-11 | jdtls excluded from automatic_enable            | Prevents dual-attachment: mason-lspconfig + ftplugin would start two jdtls instances.                                                                                                                             |
| 2026-02-11 | google-java-format default style (2-space)      | User preference: 2-space everywhere. Removed --aosp flag (4-space). Python-only exception.                                                                                                                        |
| 2026-02-11 | 4-space indent only for Python                  | Removed C/C++/C#/Rust from autocmds.lua 4-space override. Everything else = 2-space.                                                                                                                              |
| 2026-02-11 | virtual_text = true, virtual_lines = false      | virtual_lines too intrusive (pushes buffer down). virtual_text + signs + underline = right balance.                                                                                                               |
| 2026-02-11 | `<leader>J` namespace for Java-specific actions | nvim-jdtls extras (organize imports, extract variable/constant/method) in ftplugin.                                                                                                                               |
| 2026-02-11 | Lombok javaagent mandatory                      | Spring Boot + Lombok is standard. Without agent, jdtls shows false errors on @Data classes.                                                                                                                       |
| 2026-02-11 | Per-project jdtls workspace dirs                | `~/.cache/nvim/jdtls/<project>/workspace`. Prevents cross-project state corruption.                                                                                                                               |
| 2026-02-11 | Debugging/testing deferred to future phase      | ftplugin bundles architecture supports adding DAP later without restructuring.                                                                                                                                    |
| 2026-02-12 | ruff LSP DROPPED for Python                     | Systemic diagnostic overlap with basedpyright. Parser errors (E702), F821, F841, W605 all duplicate. Community whack-a-mole for 1+ year (basedpyright#203, ruff-lsp#384, LazyVim#5818). No clean boundary exists. |
| 2026-02-12 | basedpyright as sole Python LSP                 | `"standard"` mode catches real bugs: types, undefined names, unused imports, syntax. Sufficient for secondary language. One server, zero duplicates.                                                              |
| 2026-02-12 | ruff_format via conform (not LSP formatting)    | Manual-only pattern. ruff_format is CLI tool, no ruff LSP needed. Formatting independent of diagnostics.                                                                                                          |
| 2026-02-12 | rust_analyzer native (not rustaceanvim)         | Primary stack is Java/TS/Python. Plain RA sufficient. Upgrade path to rustaceanvim if needed.                                                                                                                     |
| 2026-02-12 | clippy via rust-analyzer check.command          | Lint-level diagnostics alongside type errors. No external linter needed for Rust.                                                                                                                                 |
| 2026-02-12 | rustfmt via conform (not LSP formatting)        | Manual-only pattern consistent with all other languages.                                                                                                                                                          |
| 2026-02-12 | SchemaStore.nvim for jsonls + yamlls            | 400+ schemas. Reversed earlier "no jsonls/yamlls" decision — schema validation adds real value.                                                                                                                   |
| 2026-02-12 | jsonls with validate.enable = true              | Upstream bug defaults validation to false. Must set explicitly.                                                                                                                                                   |
| 2026-02-12 | yamlls disable built-in schemaStore             | Prevents conflict: `schemaStore = { enable = false, url = "" }` when SchemaStore.nvim active.                                                                                                                     |
| 2026-02-12 | lemminx for XML (LSP-only formatting)           | Only XML formatter available. Exception to "no LSP formatting" rule. workDir = ~/.cache/lemminx.                                                                                                                  |
| 2026-02-12 | taplo for TOML (formatting via conform)         | Built-in formatting + validation + schema support. Covers Cargo.toml, pyproject.toml.                                                                                                                             |
| 2026-02-12 | fish_lsp + fish_indent for Fish                 | fish_lsp in nvim-lspconfig. fish_indent ships with fish shell (built-in formatter).                                                                                                                               |
| 2026-02-12 | bashls (shellcheck auto-integrated)             | bashls includes shellcheck with 500ms debounce. DO NOT add shellcheck to nvim-lint.                                                                                                                               |
| 2026-02-12 | marksman + markdownlint-cli2 for Markdown       | marksman = LSP (links, symbols). markdownlint-cli2 = nvim-lint (only new nvim-lint entry).                                                                                                                        |
| 2026-02-12 | sql-formatter only for SQL (no LSP)             | Formatting-only via conform. No LSP needed for basic SQL usage.                                                                                                                                                   |
| 2026-02-12 | 2-space indent for Rust (not 4-space)           | User preference overrides convention. Removed Rust from autocmds.lua 4-space override.                                                                                                                            |

---

_IDEI Build Tracker — February 2026 | Neovim 0.11.x | M4 Max · HHKB Type-S_
_Constitution v2.4 compliant | Lua-first validation methodology_
