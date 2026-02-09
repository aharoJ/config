# YAZI VERB CATALOG — Blank Canvas Keybinding Architecture

> For aharoJ's PDE rebuild. Every verb Yazi understands, tiered by frequency,
> organized for designing YOUR keymap from scratch.
> Based on: Yazi v26.1.22 (shipped defaults + full API docs)

---

## PHILOSOPHY — LESSONS FROM THE BEST

### What LF Got Right (and Yazi inherited)

LF's default keymap is intentionally minimal — `clearmaps` exists specifically so power users
can nuke everything and start fresh. LF's namespace conventions:

- `z` prefix → toggle settings (hidden, reverse, info)
- `s` prefix → sort modes
- `g` prefix → goto/bookmarks
- Single keys → most frequent actions (hjkl, /, n, d, y, p)
- `:` → command mode (like vim)

### What Ranger Established

Ranger set the miller-columns convention and vim-grammar approach:

- Navigation mirrors vim exactly (hjkl, gg, G, C-u, C-d)
- File ops mirror vim metaphors (y=yank/copy, d=cut, p=paste)
- `g` prefix for "go to" destinations
- `,` for sort cycling
- Visual mode with `v`

### What Power Users Actually Change

From studying 20+ elite configs across LF, Ranger, and Yazi:

1. **q/Q swap** — Most people want cd-on-quit as default (q), not the reverse
2. **Search promotion** — fzf/zoxide get promoted to single keys (z, Z) or better
3. **Bookmarks** — g-prefix destinations customized to actual project dirs
4. **Open-with** — Custom opener chains for their specific editor/tool stack
5. **Shell shortcuts** — Direct bindings to lazygit, nvim, tmux actions
6. **Help** — Moved from `~` to `?` (more intuitive)
7. **Linemode/sort** — Prefix kept (`,` and `m`) but trimmed to what they use

### The Blank Canvas Principle

> "Make the apps fit your preferences" — Every binding should exist because
> YOU decided it earns that key, not because it was a default you never questioned.

---

## PART 1 — THE COMPLETE VERB CATALOG ([mgr] layer)

Every command Yazi's manager layer understands, with all options.

### LIFECYCLE

| Verb      | Options                                                           | What It Does                                      |
| --------- | ----------------------------------------------------------------- | ------------------------------------------------- |
| `quit`    | `--no-cwd-file`, `--code=[n]`                                     | Exit Yazi process                                 |
| `close`   | `--no-cwd-file`, `--code=[n]`                                     | Close current tab; quit if last                   |
| `suspend` | —                                                                 | Pause Yazi, return to parent shell (fg to resume) |
| `escape`  | `--all`, `--find`, `--visual`, `--select`, `--filter`, `--search` | Cancel active mode/selection                      |

### NAVIGATION — Moving Through the Filesystem

| Verb      | Options                                             | What It Does                                |
| --------- | --------------------------------------------------- | ------------------------------------------- |
| `arrow`   | `[n]`, `[n%]`, `"top"`, `"bot"`, `"prev"`, `"next"` | Move cursor in file list                    |
| `leave`   | —                                                   | Go to parent directory                      |
| `enter`   | —                                                   | Enter child directory                       |
| `back`    | —                                                   | Previous directory in history               |
| `forward` | —                                                   | Next directory in history                   |
| `cd`      | `[url]`, `--interactive`                            | Change directory                            |
| `reveal`  | `[url]`                                             | Hover over specific file (even across dirs) |
| `follow`  | —                                                   | Follow symlink to target                    |

**`arrow` values explained:**

- `arrow -1` / `arrow 1` — up/down one, stops at boundaries
- `arrow prev` / `arrow next` — up/down one, WRAPS around (circular)
- `arrow -50%` / `arrow 50%` — half page up/down
- `arrow -100%` / `arrow 100%` — full page up/down
- `arrow top` / `arrow bot` — first/last item

### SELECTION

| Verb              | Options          | What It Does                              |
| ----------------- | ---------------- | ----------------------------------------- |
| `toggle`          | `--state=on/off` | Toggle/set selection on hovered file      |
| `toggle_all`      | `--state=on/off` | Toggle/set selection on all files in CWD  |
| `visual_mode`     | `--unset`        | Enter visual mode (select range)          |
| `escape --select` | —                | Deselect ALL files across ALL directories |

### FILE OPERATIONS

| Verb       | Options                                                                | What It Does                                  |
| ---------- | ---------------------------------------------------------------------- | --------------------------------------------- |
| `open`     | `--interactive`, `--hovered`                                           | Open file(s) with configured opener           |
| `yank`     | `--cut`                                                                | Copy (or cut) selected files                  |
| `unyank`   | —                                                                      | Cancel yank status                            |
| `paste`    | `--force`, `--follow`                                                  | Paste yanked files                            |
| `link`     | `--relative`, `--force`                                                | Create symlink to yanked files                |
| `hardlink` | `--force`, `--follow`                                                  | Create hardlink to yanked files               |
| `remove`   | `--permanently`, `--force`, `--hovered`                                | Trash or delete files                         |
| `create`   | `--dir`, `--force`                                                     | Create file (or dir if ends with /)           |
| `rename`   | `--cursor=…`, `--empty=…`, `--hovered`, `--force`                      | Rename file(s), bulk rename if multi-selected |
| `copy`     | `"path"`, `"dirname"`, `"filename"`, `"name_without_ext"`, `--hovered` | Copy path/name to clipboard                   |

**`rename --cursor` options:** `"end"`, `"start"`, `"before_ext"`
**`rename --empty` options:** `"stem"`, `"ext"`, `"dot_ext"`, `"all"`

### PREVIEW & INSPECTION

| Verb   | Options | What It Does                                     |
| ------ | ------- | ------------------------------------------------ |
| `seek` | `[n]`   | Scroll preview pane (negative=up, positive=down) |
| `spot` | —       | Open spotter (file info popup)                   |

### SEARCH & DISCOVERY

| Verb         | Options                                  | What It Does                              |
| ------------ | ---------------------------------------- | ----------------------------------------- |
| `search`     | `--via=fd/rg/rga`, `--args="…"`          | Search files by name (fd) or content (rg) |
| `search_do`  | `--via=…`, `--args="…"`                  | Execute search directly (e.g., flat view) |
| `find`       | `--previous`, `--smart`, `--insensitive` | Incremental find in CWD                   |
| `find_arrow` | `--previous`                             | Jump to next/prev find match              |
| `filter`     | `--smart`, `--insensitive`               | Live filter file list                     |

### DISPLAY & SORTING

| Verb       | Options                                                              | What It Does                   |
| ---------- | -------------------------------------------------------------------- | ------------------------------ |
| `hidden`   | `"show"`, `"hide"`, `"toggle"`                                       | Control hidden file visibility |
| `linemode` | `"none"`, `"size"`, `"btime"`, `"mtime"`, `"permissions"`, `"owner"` | Right-side file info display   |
| `sort`     | `[by]`, `--reverse`, `--dir-first`, `--translit`                     | Sort file list                 |

**`sort [by]` options:** `"none"`, `"mtime"`, `"btime"`, `"extension"`, `"alphabetical"`, `"natural"`, `"size"`, `"random"`

### TABS

| Verb         | Options              | What It Does                         |
| ------------ | -------------------- | ------------------------------------ |
| `tab_create` | `[url]`, `--current` | Create new tab                       |
| `tab_close`  | `[n]`                | Close tab at position n              |
| `tab_switch` | `[n]`, `--relative`  | Switch to tab (absolute or relative) |
| `tab_swap`   | `[n]`                | Swap current tab with another        |

### SHELL & PLUGINS

| Verb     | Options                                                          | What It Does          |
| -------- | ---------------------------------------------------------------- | --------------------- |
| `shell`  | `[template]`, `--block`, `--orphan`, `--interactive`, `--cursor` | Run shell command     |
| `plugin` | `[name]`, args                                                   | Run Lua plugin        |
| `help`   | —                                                                | Open help menu        |
| `noop`   | —                                                                | Disable a key (no-op) |

**Shell template variables:**

- `%h` — hovered file path
- `%s` — all selected file paths
- `%sN` — Nth selected file
- `%d` / `%dN` — directory paths
- `%%` — literal %

### TASKS (cross-layer)

| Verb          | Context | What It Does                |
| ------------- | ------- | --------------------------- |
| `tasks:show`  | [mgr]   | Show task manager           |
| `input:close` | [cmp]   | Close input from completion |

---

## PART 2 — OTHER LAYERS (Complete)

### [input] — Rename/Create/CD Input Box

This is a full vi-mode editor. All verbs:

**Mode switching:** `insert`, `insert --append`, `visual`, `replace`, `escape`, `close`, `close --submit`
**Movement:** `move [n]`, `move bol/eol/first-char`, `backward`, `backward --far`, `forward`, `forward --end-of-word`, `forward --far`
**Editing:** `backspace`, `backspace --under`, `kill bol/eol/backward/forward`, `delete --cut`, `delete --cut --insert`, `yank`, `paste`, `paste --before`
**Undo:** `undo`, `redo`, `casefy lower/upper`

### [tasks] — Task Manager

`close`, `arrow`, `inspect`, `cancel`, `help`

### [spot] — File Spotter

`close`, `arrow`, `swipe [n]`, `copy cell`, `help`

### [pick] — Open-With Picker

`close`, `close --submit`, `arrow`, `help`

### [confirm] — Confirmation Dialog

`close`, `close --submit`, `arrow`, `help`

### [cmp] — Completion Popup

`close`, `close --submit`, `arrow`, `help`

### [help] — Help Menu

`escape`, `close`, `arrow`, `filter`

---

## PART 3 — FREQUENCY TIERS (Your Workflow)

Based on a Spring Boot + React/Next.js developer navigating codebases,
config dirs, and project roots daily.

### 🔴 TIER 1 — MUSCLE MEMORY (100+ times/day → single keys)

These deserve the best real estate on your keyboard.

| Action           | Why                     | Yazi Verb                              |
| ---------------- | ----------------------- | -------------------------------------- |
| Move up/down     | Constant                | `arrow prev/next` or `arrow -1/1`      |
| Enter directory  | Constant                | `enter`                                |
| Go to parent     | Constant                | `leave`                                |
| Open file (nvim) | Constant                | `open` or `open --hovered`             |
| Quit (cd to dir) | End of every session    | `quit`                                 |
| Toggle hidden    | Multiple times daily    | `hidden toggle`                        |
| Quick filter     | Finding files fast      | `filter --smart`                       |
| Quick find       | Jumping to file by name | `find --smart`                         |
| Find next/prev   | After finding           | `find_arrow` / `find_arrow --previous` |
| Escape/cancel    | Constant                | `escape`                               |
| Select/toggle    | Batch operations        | `toggle` + `arrow`                     |

### 🟡 TIER 2 — DAILY OPERATIONS (10-50 times/day → comfortable keys or 2-key chords)

| Action             | Why                  | Yazi Verb                     |
| ------------------ | -------------------- | ----------------------------- |
| Copy files         | File management      | `yank`                        |
| Cut files          | File management      | `yank --cut`                  |
| Paste files        | File management      | `paste`                       |
| Delete/trash       | Cleanup              | `remove`                      |
| Rename             | Refactoring          | `rename --cursor=before_ext`  |
| Create file/dir    | New files            | `create`                      |
| Search via fd      | Finding across tree  | `search --via=fd`             |
| Search via rg      | Grep through files   | `search --via=rg`             |
| Copy path          | Share paths          | `copy path`                   |
| Copy filename      | Quick reference      | `copy filename`               |
| Open interactively | Choose opener        | `open --interactive`          |
| Shell interactive  | Quick commands       | `shell --interactive`         |
| Shell blocking     | Interactive programs | `shell --block --interactive` |
| Goto bookmarks     | Project jumping      | `cd [path]`                   |
| Goto interactive   | Freeform cd          | `cd --interactive`            |
| fzf jump           | Fuzzy find           | `plugin fzf`                  |
| zoxide jump        | Frecency cd          | `plugin zoxide`               |
| Page up/down       | Scrolling long dirs  | `arrow -50%/50%`              |
| Top/bottom         | Jump to edges        | `arrow top/bot`               |
| Back/forward       | Dir history          | `back` / `forward`            |
| Preview scroll     | Reading previews     | `seek -5` / `seek 5`          |
| Spotter            | File info            | `spot`                        |
| Visual mode        | Range select         | `visual_mode`                 |
| Select all         | Batch ops            | `toggle_all --state=on`       |

### 🟢 TIER 3 — WEEKLY/OCCASIONAL (1-10 times/day → 2-key chords are fine)

| Action             | Why                  | Yazi Verb                    |
| ------------------ | -------------------- | ---------------------------- |
| Sort by size       | Disk cleanup         | `sort size`                  |
| Sort by mtime      | Recent files         | `sort mtime`                 |
| Sort by name       | Reset sort           | `sort natural`               |
| Linemode: size     | See sizes            | `linemode size`              |
| Linemode: mtime    | See dates            | `linemode mtime`             |
| Linemode: perms    | Check perms          | `linemode permissions`       |
| Symlink            | Linking              | `link` / `link --relative`   |
| Hardlink           | Rare                 | `hardlink`                   |
| Unyank             | Cancel copy          | `unyank`                     |
| Bulk rename        | Multi-file rename    | `rename` (with multi-select) |
| Permanently delete | Dangerous            | `remove --permanently`       |
| Paste force        | Overwrite            | `paste --force`              |
| Copy dirname       | Path sharing         | `copy dirname`               |
| Copy name no ext   | Specific need        | `copy name_without_ext`      |
| Cancel search      | After searching      | `escape --search`            |
| Flat view          | Deep search          | `search_do --via=fd`         |
| Follow symlink     | Inspect link target  | `follow`                     |
| Suspend            | Background yazi      | `suspend`                    |
| Tasks show         | Check background ops | `tasks:show`                 |
| Help               | Reference            | `help`                       |

### 🔵 TIER 4 — RARE (tabs, advanced)

| Action           | Why            | Yazi Verb                    |
| ---------------- | -------------- | ---------------------------- |
| Create tab       | Multi-location | `tab_create --current`       |
| Switch tabs 1-9  | Tab management | `tab_switch [n]`             |
| Prev/next tab    | Tab cycling    | `tab_switch -1/1 --relative` |
| Swap tabs        | Tab reordering | `tab_swap`                   |
| Close tab        | Tab cleanup    | `close`                      |
| Invert selection | Rare           | `toggle_all`                 |
| Reveal file      | From external  | `reveal`                     |

---

## PART 4 — NAMESPACE ARCHITECTURE

Design your namespaces FIRST, then assign keys.

### Recommended Namespace System

```
SINGLE KEYS          → Tier 1 actions (navigation, open, quit, filter, find)
g + key              → GOTO destinations (bookmarks, special dirs)
c + key              → COPY to clipboard (path, dirname, filename, stem)
, + key              → SORT modes (+ auto linemode switch)
m + key              → LINEMODE display toggles
e + key              → EDIT/OPEN-WITH (nvim, vscode, $EDITOR, interactive)
o + key              → OPEN/EXTERNAL (finder, tmux, browser)
z + key              → JUMP tools (fzf, zoxide, interactive cd)
; / :                → SHELL (interactive / blocking)
```

### Cross-Tool Consistency (Your PDE)

| Concept       | Neovim      | Yazi                       | Rationale                            |
| ------------- | ----------- | -------------------------- | ------------------------------------ |
| Leader        | `<Space>`   | N/A (no leader concept)    | Yazi uses single keys                |
| Navigation    | hjkl        | hjkl                       | Vim-native                           |
| Search        | `/`         | `/` (find), `s/S` (search) | Vim-native for find                  |
| Next match    | `n/N`       | `n/N`                      | Vim-native                           |
| File tree     | `<leader>e` | Yazi IS the tree           | —                                    |
| Save          | `<leader>w` | N/A                        | —                                    |
| Quit          | `:q`        | `q`                        | Same key, simpler                    |
| Copy          | `y`         | `y`                        | Vim-native yank                      |
| Cut           | `d` (void)  | `x`                        | Yazi convention                      |
| Paste         | `p`         | `p`                        | Vim-native                           |
| Delete        | —           | `d`                        | Yazi convention                      |
| Visual mode   | `v`         | `v`                        | Consistent                           |
| Select all    | `<leader>a` | `<C-a>`                    | Both use 'a'                         |
| Rename        | LSP rename  | `r`                        | Single key                           |
| New file      | —           | `a`                        | Yazi convention ('a' for add/create) |
| Hidden toggle | —           | `.`                        | Universal convention                 |

### Keys Available for Single-Key Binds (HHKB-friendly)

After reserving hjkl (nav), g (goto prefix), c (copy prefix), , (sort prefix), m (linemode prefix):

```
LOWERCASE AVAILABLE:
  a — create (established convention)
  b — ??? (free)
  d — remove/trash
  e — edit prefix (your convention)
  f — filter
  i — ??? (free — maybe inspect/info?)
  n — find next
  o — open prefix (your convention)
  p — paste
  q — quit (cd)
  r — rename
  s — search fd
  t — tab create? or free
  u — ??? (free — maybe unyank? undo?)
  v — visual mode
  w — tasks show
  x — yank cut
  y — yank copy
  z — jump prefix (your convention)

UPPERCASE AVAILABLE:
  D — remove permanently
  H — back (dir history)
  J — seek down (preview)
  K — seek up (preview)
  L — forward (dir history)
  N — find previous
  O — open interactive
  P — paste force
  Q — quit (no cd)
  R — ??? (reveal in finder? your current binding)
  S — search rg
  V — visual mode unset
  X — unyank
  Y — unyank (or your clipboard copy)

SYMBOLS:
  . — hidden toggle
  / — find
  ? — find previous (or help)
  ; — shell interactive
  : — shell blocking
  - — symlink
  _ — symlink relative
  <Space> — toggle + arrow (select)
  <Tab> — spot
  <Enter> — open
  ~ — help (default) or free
  ! — open $SHELL here (common convention)

CTRL (HHKB home-row friendly):
  <C-a> — select all
  <C-c> — close/cancel
  <C-d> — half page down
  <C-u> — half page up
  <C-f> — full page down
  <C-b> — full page up
  <C-r> — invert selection
  <C-s> — cancel search
  <C-z> — suspend
  <C--> — hardlink
```

---

## PART 5 — DEFAULT vs YOUR CURRENT vs DECISION MATRIX

For each action, here's what the default does, what you currently have, and a column for your decision.

| Action                    | Default Key       | Your Current Key               | Notes                                      |
| ------------------------- | ----------------- | ------------------------------ | ------------------------------------------ |
| **Quit (cd)**             | `q`               | `Q`                            | You swapped q/Q — deliberate               |
| **Quit (no cd)**          | `Q`               | `q`                            | You swapped q/Q — deliberate               |
| **Escape**                | `<Esc>`           | `<Esc>`                        | Keep                                       |
| **Close tab**             | `<C-c>`           | `<C-c>`                        | Keep                                       |
| **Suspend**               | `<C-z>`           | `<C-z>`                        | Keep                                       |
| **Up/Down**               | `k/j`             | `k/j`                          | Keep                                       |
| **Enter dir**             | `l`               | `l`                            | Keep                                       |
| **Leave dir**             | `h`               | `h`                            | Keep                                       |
| **Half page**             | `<C-u>/<C-d>`     | `<C-u>/<C-d>`                  | Keep                                       |
| **Full page**             | `<C-b>/<C-f>`     | `<C-b>/<C-f>`                  | Keep                                       |
| **Top/Bottom**            | `gg/G`            | `gg/G`                         | Keep                                       |
| **Dir back**              | `H`               | `H`                            | Keep                                       |
| **Dir forward**           | `L`               | `L`                            | Keep                                       |
| **Toggle select**         | `<Space>`         | `<Space>`                      | Keep                                       |
| **Select all**            | `<C-a>`           | `<C-a>`                        | Keep                                       |
| **Invert select**         | `<C-r>`           | `<C-r>`                        | Keep                                       |
| **Visual mode**           | `v/V`             | `v/V`                          | Keep                                       |
| **Seek preview**          | `K/J`             | `K/J`                          | Keep                                       |
| **Spot**                  | `<Tab>`           | ❌ MISSING                     | Add — killer feature                       |
| **Open**                  | `o` / `<Enter>`   | `<Enter>` (hovered only)       | You use Enter, removed `o` for open prefix |
| **Open interactive**      | `O` / `<S-Enter>` | `[e,w,o]` → interactive        | Your e/w namespace                         |
| **Yank (copy)**           | `y`               | `y`                            | Keep                                       |
| **Yank (cut)**            | `x`               | `x`                            | Keep                                       |
| **Paste**                 | `p`               | `p`                            | Keep                                       |
| **Paste force**           | `P`               | `P`                            | Keep                                       |
| **Symlink**               | `-`               | `-`                            | Keep                                       |
| **Symlink relative**      | `_`               | `_`                            | Keep                                       |
| **Hardlink**              | `<C-->`           | `<C-->`                        | Keep                                       |
| **Unyank**                | `Y` / `X`         | `Y` / `X`                      | Keep (but you have Y for clipboard)        |
| **Remove (trash)**        | `d`               | `d`                            | Keep                                       |
| **Remove (perm)**         | `D`               | `D`                            | Keep                                       |
| **Create**                | `a`               | `a`                            | Keep                                       |
| **Rename**                | `r`               | `r`                            | Keep                                       |
| **Shell interactive**     | `;`               | `;`                            | Keep                                       |
| **Shell blocking**        | `:`               | `:`                            | Keep                                       |
| **Hidden toggle**         | `.`               | `.`                            | Keep                                       |
| **Search fd**             | `s`               | `s`                            | Keep                                       |
| **Search rg**             | `S`               | `S`                            | Keep                                       |
| **Cancel search**         | `<C-s>`           | `<C-s>`                        | Keep                                       |
| **fzf**                   | `z`               | ❌ z is goto prefix            | Conflict — need to relocate                |
| **zoxide**                | `Z`               | ❌ Not bound                   | Need to add                                |
| **Filter**                | `f`               | `f`                            | Keep                                       |
| **Find**                  | `/`               | `/`                            | Keep                                       |
| **Find prev**             | `?`               | `?`                            | Keep                                       |
| **Find next**             | `n`               | `n`                            | Keep                                       |
| **Find prev**             | `N`               | `N`                            | Keep                                       |
| **Linemode**              | `m+key`           | `m+key`                        | Keep                                       |
| **Sort**                  | `,+key`           | `,+key`                        | Keep                                       |
| **Copy path**             | `c,c`             | `c,c`                          | Keep                                       |
| **Copy dirname**          | `c,d`             | `c,d`                          | Keep                                       |
| **Copy filename**         | `c,f`             | `c,f`                          | Keep                                       |
| **Copy stem**             | `c,n`             | `c,n`                          | Keep                                       |
| **Goto home**             | `g,h`             | `g,h`                          | Keep                                       |
| **Goto config**           | `g,c`             | `g,c`                          | Keep                                       |
| **Goto downloads**        | `g,d`             | `g,d`                          | Keep                                       |
| **Goto interactive**      | `g,<Space>`       | `g,<Space>`                    | Keep                                       |
| **Follow symlink**        | `g,f`             | ❌ MISSING                     | Add                                        |
| **Tab create**            | `t`               | `t`                            | Keep                                       |
| **Tab switch 1-9**        | `1-9`             | `1-9`                          | Keep                                       |
| **Tab prev/next**         | `[/]`             | `[/]`                          | Keep                                       |
| **Tab swap**              | `{/}`             | `{/}`                          | Keep                                       |
| **Tasks show**            | `w`               | `w` (⚠️ uses old `tasks_show`) | FIX → `tasks:show`                         |
| **Help**                  | `~/F1`            | `~/F1`                         | Consider `?` swap                          |
| **YOUR: edit/with**       | N/A               | `e,w,*` namespace              | Custom — keep                              |
| **YOUR: open/with**       | N/A               | `o,w,*` namespace              | Custom — keep                              |
| **YOUR: open/tmux**       | N/A               | `o,t,*` namespace              | Custom — keep                              |
| **YOUR: z/to bookmarks**  | N/A               | `z,t,*` namespace              | Custom — keep                              |
| **YOUR: clipboard copy**  | N/A               | `Y`                            | Conflicts with default unyank              |
| **YOUR: reveal finder**   | N/A               | `R`                            | Custom — keep                              |
| **YOUR: open finder pwd** | N/A               | `F`                            | Custom — keep                              |

---

## PART 6 — DECISIONS TO MAKE

These are the genuine design choices where your preference matters.

### 1. Wraparound Navigation?

- `arrow prev/next` (wraps) vs `arrow -1/1` (stops at edges)
- Your current: stops at edges
- Recommendation: personal preference, most power users prefer wrapping

### 2. Where Do fzf and zoxide Live?

- Default: `z` = fzf, `Z` = zoxide
- Your current: `z` is claimed by z/to/\* bookmarks
- Options:
  - Move bookmarks to `g,b,*` (go/bookmark/\*) and reclaim `z/Z` for fzf/zoxide
  - Put fzf on `g,z` and zoxide on `g,Z` (under goto namespace)
  - Put them on `z,f` (z/fzf) and `z,z` (z/zoxide) within your z namespace

### 3. Help: `~` or `?`

- Default: `~` (unusual), `?` is find-previous
- Many users swap `?` to help (like less/man)
- If you swap: find-previous needs a new home (maybe `<S-/>` or just use `N`)

### 4. Open: `o` or `<Enter>` as primary?

- Default: both `o` and `<Enter>` do `open`
- You use `<Enter>` (hovered), and claimed `o` for open/with namespace
- This is clean — keep it

### 5. Unyank Collision

- Default: `Y` and `X` both do unyank
- You have `Y` → copy file contents to clipboard
- Decision: drop one of Y/X for unyank, keep the other for your clipboard copy

### 6. Tab Key Usage

- You haven't bound `<Tab>` — the spotter is available
- Spotter is genuinely useful (quick file info without opening)
- Strong recommendation: add `<Tab>` → `spot`

### 7. `!` for Shell?

- Common convention (from Vim's `:!`): `!` → open $SHELL here
- Currently unbound in your config
- Consider: `{ on = "!", run = 'shell "$SHELL" --block', desc = "Open shell here" }`

---

## PART 7 — [input] LAYER AUDIT

The input layer is where you type during rename, create, cd, filter, etc.
Your current input layer is THIN. The defaults give you a full vi-mode editor.

### What You're Missing (worth having)

| Binding         | Action                           | Why                            |
| --------------- | -------------------------------- | ------------------------------ |
| `h/l`           | move -1/1                        | Cursor movement in normal mode |
| `0/$`           | move bol/eol                     | Line start/end                 |
| `^/_`           | move first-char                  | First non-whitespace           |
| `w/b/e`         | forward/backward/end-of-word     | Word movement                  |
| `W/B/E`         | forward --far / backward --far   | WORD movement                  |
| `i/I`           | insert / insert at BOL           | Enter insert mode              |
| `a/A`           | append / append at EOL           | Enter append mode              |
| `v/V`           | visual / select line             | Visual selection               |
| `r`             | replace char                     | Quick fix                      |
| `d/c/s/x/y/p/P` | Cut/change/substitute/yank/paste | Full vim editing               |
| `u/U`           | undo + lowercase / uppercase     | Undo + case                    |
| `<C-r>`         | redo                             | Redo                           |
| `<C-u>/<C-k>`   | kill to BOL/EOL                  | Line editing                   |
| `<C-w>`         | kill backward word               | Word delete                    |

**Recommendation:** Adopt the full default [input] keymap. It's a proper vi-mode and
you'll want all of it when renaming files or typing paths.

---

_Catalog version: 2026-02-09 | Yazi v26.1.22 | For PDE rebuild_
