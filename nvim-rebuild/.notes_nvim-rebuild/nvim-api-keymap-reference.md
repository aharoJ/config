# Neovim 0.11+ API Keymap Reference

> Every actionable function across LSP, Diagnostics, and Inlay Hints.
> For each: the function signature, whether Neovim maps a default keybind, and what that keybind is.
>
> **Legend:**
>
> - ✅ = 0.11+ default keybind exists (DO NOT override unless intentional)
> - ❌ = No default keybind (bind it yourself or call manually)
> - 🔧 = Configuration/query function (not an action — no keybind needed)

---

## vim.lsp.buf — LSP Buffer Actions

### Navigation

| Function                        | Default Keybind | Mode   | Notes                                                                                  |
| ------------------------------- | --------------- | ------ | -------------------------------------------------------------------------------------- |
| `vim.lsp.buf.definition()`      | ❌ None         | —      | Common custom: `gd`. Also reachable via `<C-]>` through `tagfunc` (set automatically). |
| `vim.lsp.buf.declaration()`     | ❌ None         | —      | Common custom: `gD`                                                                    |
| `vim.lsp.buf.references()`      | ✅ `grr`        | Normal |                                                                                        |
| `vim.lsp.buf.implementation()`  | ✅ `gri`        | Normal |                                                                                        |
| `vim.lsp.buf.type_definition()` | ✅ `grt`        | Normal | Added in 0.12 HEAD, backported to late 0.11.x                                          |
| `vim.lsp.buf.document_symbol()` | ✅ `gO`         | Normal | Opens in quickfix/loclist                                                              |

### Information

| Function                       | Default Keybind | Mode           | Notes                                                                           |
| ------------------------------ | --------------- | -------------- | ------------------------------------------------------------------------------- |
| `vim.lsp.buf.hover()`          | ✅ `K`          | Normal         | Set conditionally: only if `keywordprg` is default and no custom `K` map exists |
| `vim.lsp.buf.signature_help()` | ✅ `<C-s>`      | Insert, Select | If using blink.cmp signature, this is redundant                                 |

### Refactoring

| Function                    | Default Keybind | Mode           | Notes                                                                                                                                                                    |
| --------------------------- | --------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `vim.lsp.buf.rename()`      | ✅ `grn`        | Normal         |                                                                                                                                                                          |
| `vim.lsp.buf.code_action()` | ✅ `gra`        | Normal, Visual |                                                                                                                                                                          |
| `vim.lsp.buf.format()`      | ❌ None         | —              | `gq` uses `formatexpr` (set to `vim.lsp.formatexpr()` automatically), but that's not the same as calling `format()` directly. If using conform.nvim, this is irrelevant. |

### Workspace

| Function                                | Default Keybind | Mode | Notes                       |
| --------------------------------------- | --------------- | ---- | --------------------------- |
| `vim.lsp.buf.workspace_symbol()`        | ❌ None         | —    | Common custom: `<leader>ws` |
| `vim.lsp.buf.add_workspace_folder()`    | ❌ None         | —    | Rarely bound                |
| `vim.lsp.buf.remove_workspace_folder()` | ❌ None         | —    | Rarely bound                |
| `vim.lsp.buf.list_workspace_folders()`  | ❌ None         | —    | Rarely bound                |

### Selection

| Function                        | Default Keybind | Mode                     | Notes                                               |
| ------------------------------- | --------------- | ------------------------ | --------------------------------------------------- |
| `vim.lsp.buf.selection_range()` | ✅ `an` / `in`  | Visual, Operator-pending | Incremental selection (outer/inner). 0.12+ feature. |

### Advanced

| Function                              | Default Keybind | Mode | Notes                                 |
| ------------------------------------- | --------------- | ---- | ------------------------------------- |
| `vim.lsp.buf.typehierarchy()`         | ❌ None         | —    | Subtypes/supertypes in quickfix       |
| `vim.lsp.buf.workspace_diagnostics()` | ❌ None         | —    | Pull diagnostics for entire workspace |
| `vim.lsp.buf.incoming_calls()`        | ❌ None         | —    | Call hierarchy                        |
| `vim.lsp.buf.outgoing_calls()`        | ❌ None         | —    | Call hierarchy                        |

### Buffer-Local Options (set automatically on LspAttach)

These are not keymaps but options Neovim sets when an LSP client attaches:

| Option       | Set To                 | Effect                                                 |
| ------------ | ---------------------- | ------------------------------------------------------ |
| `omnifunc`   | `vim.lsp.omnifunc()`   | `<C-x><C-o>` triggers LSP completion                   |
| `tagfunc`    | `vim.lsp.tagfunc()`    | `<C-]>`, `:tjump` use LSP definitions                  |
| `formatexpr` | `vim.lsp.formatexpr()` | `gq` uses LSP formatting (clear if using conform.nvim) |

---

## vim.diagnostic — Diagnostic Actions

### Navigation

| Function                              | Default Keybind | Mode   | Notes                              |
| ------------------------------------- | --------------- | ------ | ---------------------------------- |
| `vim.diagnostic.jump({ count = 1 })`  | ✅ `]d`         | Normal | Next diagnostic (any severity)     |
| `vim.diagnostic.jump({ count = -1 })` | ✅ `[d`         | Normal | Previous diagnostic (any severity) |
| `vim.diagnostic.jump()` (first)       | ✅ `[D`         | Normal | First diagnostic in buffer         |
| `vim.diagnostic.jump()` (last)        | ✅ `]D`         | Normal | Last diagnostic in buffer          |
| `vim.diagnostic.open_float()`         | ✅ `<C-w>d`     | Normal | Also `<C-w><C-d>`                  |

### Lists

| Function                      | Default Keybind | Mode | Notes                                                        |
| ----------------------------- | --------------- | ---- | ------------------------------------------------------------ |
| `vim.diagnostic.setloclist()` | ❌ None         | —    | Buffer diagnostics → location list                           |
| `vim.diagnostic.setqflist()`  | ❌ None         | —    | All diagnostics → quickfix list                              |
| `vim.diagnostic.toqflist()`   | 🔧 N/A          | —    | Convert diagnostic list to qf items (utility, not an action) |
| `vim.diagnostic.fromqflist()` | 🔧 N/A          | —    | Convert qf items to diagnostic list (utility)                |

### Toggle / Control

| Function                      | Default Keybind | Mode | Notes                                                 |
| ----------------------------- | --------------- | ---- | ----------------------------------------------------- |
| `vim.diagnostic.enable()`     | ❌ None         | —    | Enable diagnostics (accepts `true`/`false` to toggle) |
| `vim.diagnostic.is_enabled()` | 🔧 N/A          | —    | Query function, not an action                         |
| `vim.diagnostic.show()`       | ❌ None         | —    | Display diagnostics for namespace/buffer              |
| `vim.diagnostic.hide()`       | ❌ None         | —    | Hide diagnostics without disabling                    |
| `vim.diagnostic.reset()`      | ❌ None         | —    | Clear and redraw diagnostics                          |

### Configuration

| Function                  | Default Keybind | Mode | Notes                                                        |
| ------------------------- | --------------- | ---- | ------------------------------------------------------------ |
| `vim.diagnostic.config()` | 🔧 N/A          | —    | Configure display options (virtual_text, signs, float, etc.) |
| `vim.diagnostic.get()`    | 🔧 N/A          | —    | Retrieve diagnostics for a buffer                            |
| `vim.diagnostic.set()`    | 🔧 N/A          | —    | Set diagnostics for a namespace/buffer (producer API)        |
| `vim.diagnostic.count()`  | 🔧 N/A          | —    | Count diagnostics by severity                                |
| `vim.diagnostic.status()` | 🔧 N/A          | —    | Formatted string like `E:2 W:3` (statusline use)             |

---

## vim.lsp.inlay_hint — Inlay Hints

| Function                          | Default Keybind | Mode | Notes                                       |
| --------------------------------- | --------------- | ---- | ------------------------------------------- |
| `vim.lsp.inlay_hint.enable()`     | ❌ None         | —    | Accepts `true`/`false` + `{ bufnr }` filter |
| `vim.lsp.inlay_hint.is_enabled()` | 🔧 N/A          | —    | Query function                              |
| `vim.lsp.inlay_hint.get()`        | 🔧 N/A          | —    | Retrieve inlay hints for a range            |

---

## vim.lsp.document_color — Document Colors (0.12+)

| Function                          | Default Keybind | Mode | Notes                                                                            |
| --------------------------------- | --------------- | ---- | -------------------------------------------------------------------------------- |
| `vim.lsp.document_color.enable()` | ❌ None         | —    | Enabled by default on LspAttach in 0.12. Call `enable(false, bufnr)` to opt out. |

---

## Built-in Navigation Defaults (vim-unimpaired style, 0.11+)

These are NOT LSP-specific — they work in any buffer:

### Quickfix

| Keybind  | Action                 |
| -------- | ---------------------- |
| `]q`     | Next quickfix item     |
| `[q`     | Previous quickfix item |
| `]Q`     | Last quickfix item     |
| `[Q`     | First quickfix item    |
| `]<C-q>` | Next quickfix file     |
| `[<C-q>` | Previous quickfix file |

### Location List

| Keybind  | Action                      |
| -------- | --------------------------- |
| `]l`     | Next location list item     |
| `[l`     | Previous location list item |
| `]L`     | Last location list item     |
| `[L`     | First location list item    |
| `]<C-l>` | Next location list file     |
| `[<C-l>` | Previous location list file |

### Tag Matchlist

| Keybind  | Action                  |
| -------- | ----------------------- |
| `]t`     | Next tag match          |
| `[t`     | Previous tag match      |
| `]T`     | Last tag match          |
| `[T`     | First tag match         |
| `]<C-t>` | Next tag match file     |
| `[<C-t>` | Previous tag match file |

---

## Other Built-in Defaults (no plugins needed)

| Keybind              | Function                         | Since                           |
| -------------------- | -------------------------------- | ------------------------------- |
| `gcc` / `gc{motion}` | Toggle comment                   | 0.10+                           |
| `gx`                 | Open filepath/URL under cursor   | 0.10+                           |
| `gq`                 | Format via `formatexpr`          | Legacy vim (LSP-aware in 0.11+) |
| `<C-]>`              | Jump to definition via `tagfunc` | Legacy vim (LSP-aware in 0.11+) |

---

_Reference built from: neovim.io/doc/user/lsp.html, neovim.io/doc/user/diagnostic.html, news-0.11, news-0.12_
_Neovim 0.11.x target (0.12 HEAD noted where applicable) | February 2026_
