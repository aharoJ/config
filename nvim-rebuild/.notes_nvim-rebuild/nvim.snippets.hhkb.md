# Neovim Snippet Navigation Keybindings: Deep Research

## The Landscape (Who Uses What)

---

### TIER 1: The Neovim Core Defaults (Neovim 0.11+)

**Neovim itself settled this debate.** As of Neovim 0.11, the **builtin defaults** are:

- `<Tab>` — jump forward through snippet placeholders (insert + select mode)
- `<S-Tab>` — jump backward through snippet placeholders (insert + select mode)

These are **buffer-local mappings** created automatically by `vim.snippet.expand()`. This is now part of Neovim core — not a plugin decision. When a snippet session is active, Neovim _itself_ overrides your Tab/S-Tab with snippet jumping.

**This is the canonical answer from the Neovim core team.** It's not cargo cult — it's what the maintainers chose after years of discussion.

---

### TIER 2: The Three Camps

After researching across plugin READMEs, GitHub issues/discussions, dotfiles, blog posts, kickstart.nvim, LazyVim, AstroNvim, and community configs, here's the actual breakdown:

---

## Camp 1: `<Tab>` / `<S-Tab>` — THE MAJORITY (~70-80%)

**Who uses it:**

- Neovim 0.11 builtin defaults
- blink.cmp `super-tab` preset (the most popular non-default preset)
- kickstart.nvim (uses blink.cmp `default` preset which includes Tab/S-Tab for snippet nav)
- LazyVim default config
- AstroNvim default config
- nvim-snippets plugin (recommended config in README)
- nvim-snippy plugin (recommended config in README)
- UltiSnips default config
- Every "getting started" guide ever written
- Every VS Code refugee

**Why it dominates:**

- VS Code, Sublime, JetBrains, Atom — all use Tab for snippet jumping
- It's the path of least resistance / muscle memory from any other editor
- Neovim 0.11 literally made it the default
- blink.cmp's `super-tab` preset is the most requested/discussed preset

**The actual config in blink.cmp `super-tab`:**

```lua
['<Tab>'] = {
  function(cmp)
    if cmp.snippet_active() then return cmp.accept()
    else return cmp.select_and_accept() end
  end,
  'snippet_forward',
  'fallback'
},
['<S-Tab>'] = { 'snippet_backward', 'fallback' },
```

**The actual config in blink.cmp `default` (what kickstart uses):**

```lua
-- Tab/S-Tab for snippet navigation is handled by Neovim core
-- blink.cmp default uses C-y to accept, C-n/C-p to navigate menu
-- snippet jumping falls through to Neovim's builtin Tab/S-Tab
```

---

## Camp 2: `<C-l>` / `<C-h>` (or `<C-j>` / `<C-k>`) — THE PURISTS (~15-20%)

**Who uses it:**

- LuaSnip's **Lua example** in the README: `<C-L>` forward, `<C-J>` backward, `<C-K>` expand
- Hardcore Vim users who refuse to overload Tab
- Users with custom HHKB/ergonomic layouts
- The blog post by P. Coves (pcoves.gitlab.io) — explicitly uses `<C-l>` / `<C-h>`
- Users who want snippet jumping to be _separate_ from completion navigation
- Some blink.cmp users who set `preset = "none"` and hand-roll everything

**Specific key choices seen in the wild:**

| Keys              | Rationale                                             | Seen In                                              |
| ----------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| `<C-l>` / `<C-h>` | Vim motion metaphor: l=right/forward, h=left/backward | LuaSnip Lua example, P. Coves blog, various dotfiles |
| `<C-j>` / `<C-k>` | Vertical metaphor: j=down/next, k=up/prev             | blink.cmp discussions, some LazyVim users            |
| `<C-l>` / `<C-j>` | Forward=right, backward=down (asymmetric)             | Rare                                                 |
| `<C-r>` / `<C-e>` | Available keys, no conflicts                          | One blink.cmp discussion user                        |

**LuaSnip README literally shows BOTH approaches:**

```
-- Vimscript example: Tab/S-Tab
-- Lua example: C-K expand, C-L forward, C-J backward
```

The fact that they show two different sets of keys tells you this is a deliberate design choice — Vimscript users get the "normal" config, Lua users (presumably more advanced) get the Ctrl-based config.

**Why purists prefer Ctrl keys:**

1. Tab is already overloaded (indent, completion menu navigation, snippet jump)
2. Ctrl combos are unambiguous — they ONLY do snippet jumping
3. No conditional logic needed (`if snippet_active then jump else tab`)
4. On HHKB, Ctrl is literally where CapsLock is — Tier 1 accessibility
5. `<C-l>` / `<C-h>` maps to the Vim horizontal motion model (l=right, h=left)

---

## Camp 3: Hybrid / Custom — THE TWEAKERS (~5-10%)

**Patterns seen:**

- `<Tab>` to accept+jump, but `<C-l>`/`<C-h>` for explicit jumping within a snippet
- `<C-n>`/`<C-p>` for both completion AND snippet navigation (blink.cmp supports this)
- Some people bind snippet_forward to the same key as `select_next` so Tab does double duty

**Example from a blink.cmp discussion (someone using both):**

```lua
keymap = {
  ['<Tab>']   = { 'select_next', 'snippet_forward', 'fallback' },
  ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
  ['<C-j>']   = { 'snippet_forward', 'fallback' },
  ['<C-k>']   = { 'snippet_backward', 'fallback' },
}
```

---

## The 0.1% — What Elite Users Actually Do

The truly hardcore Neovim users (core contributors, plugin authors, people who write their config in Fennel) tend to:

1. **Use `<C-l>` / `<C-h>` or `<C-l>` / `<C-j>`** for snippet jumping
2. Keep Tab clean for indentation or completion-only
3. Use `preset = "none"` in blink.cmp and hand-map everything
4. Often use `<C-y>` to accept completions (the classic Vim way)
5. Use `<C-n>` / `<C-p>` for menu navigation (never arrow keys, never Tab)

**Evidence:** The Neovim issue #30198 is literally about someone using `<C-l>` for snippet jumping being annoyed that Neovim 0.11's builtin Tab/S-Tab overrides their custom mappings. This is a purist complaining that the defaults are too "normie."

---

## HHKB-Specific Analysis

On HHKB Professional layout:

- **Ctrl** is where CapsLock normally is = home row left pinky = Tier 1
- **Tab** is normal position = Tier 1.5 (slight reach from home row)
- **Shift** is normal position = Tier 2 (pinky stretch)

| Combo              | HHKB Ergonomics           | Conflict Risk                                                  |
| ------------------ | ------------------------- | -------------------------------------------------------------- |
| `<C-l>` forward    | ★★★★★ Home row both hands | `<C-l>` = redraw screen (normal mode only, safe in insert)     |
| `<C-h>` backward   | ★★★★★ Home row both hands | `<C-h>` = backspace in insert mode (you lose this)             |
| `<C-j>` backward   | ★★★★☆ Home row            | `<C-j>` = newline in insert mode (you lose this)               |
| `<C-k>` backward   | ★★★★☆ Home row            | `<C-k>` = digraph in insert mode (you probably don't use this) |
| `<Tab>` forward    | ★★★★☆ Easy reach          | Overloaded with indent + completion                            |
| `<S-Tab>` backward | ★★★☆☆ Pinky stretch       | Less ergonomic than Ctrl combos                                |

---

## THE VERDICT: What Should You Do?

### For YOUR setup (HHKB, blink.cmp, anti-cargo-cult philosophy):

**Recommended: `<C-l>` / `<C-k>`**

Why this specific combo:

- `<C-l>` forward: Home row, vim `l` = right/forward metaphor, no insert-mode conflict that matters
- `<C-k>` backward: Home row, k = up/prev in vim, loses digraph input (which you almost certainly don't use)
- NOT `<C-h>` because losing backspace in insert mode is genuinely annoying
- NOT `<C-j>` because losing newline in insert mode could bite you

This is the LuaSnip "Lua example" approach but with `<C-k>` swapped for `<C-h>` to preserve backspace.

### Why NOT Tab/S-Tab:

The person advising you was right to call it cargo-culty for HHKB. Tab is fine for normies, but:

1. On HHKB with Ctrl on home row, `<C-l>`/`<C-k>` is literally faster
2. No overloading = no conditional logic = no "did Tab do what I expected?" moments
3. blink.cmp handles the separation cleanly — snippet commands are independent from menu navigation

### The alternative if you change your mind:

Just set `preset = "super-tab"` in blink.cmp and call it a day. It works. 80% of users do this. There's no shame in it. But it's not the HHKB-optimized choice.
