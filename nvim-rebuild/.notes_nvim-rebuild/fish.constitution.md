# FISH SHELL CONFIGURATION CONSTITUTION (v1.0)

## PREAMBLE — READ THIS FIRST, OBEY IT ALWAYS

This constitution governs all work on my Fish shell configuration. Every file you generate, every alias you suggest, every function you write — must comply with this document. No exceptions.

Fish is **the shell** — the command-line interface to everything. It sits between me and every tool in the PDE. Unlike Neovim (which is a complex application with plugins, LSP, and treesitter), Fish is deliberately simple: environment setup, aliases, and convenience functions. The constitution reflects this — shorter, sharper, less surface area.

**Quality Bar:** Top 0.1% craftsmanship. Every function earns its place. Every line in `config.fish` has a reason. Zero junk-drawer energy.

**Fish's Philosophy — And Why We Chose It:**
Fish is opinionated by design. It works out of the box. Syntax highlighting, autosuggestions, and tab completion require zero configuration. We chose Fish *because* it requires minimal config — the constitution's job is to keep it that way.

---

## ARTICLE I — IDENTITY & CONTEXT

### Role in the PDE

```
┌─── macOS Desktop (yabai) ──────────────────────────────────┐
│  ┌─── Ghostty Window ──────────────────────────────────┐   │
│  │  ┌─── tmux session ────────────────────────────┐    │   │
│  │  │  ┌─── tmux pane ─────┐ ┌─── tmux pane ───┐ │    │   │
│  │  │  │                   │ │                   │ │    │   │
│  │  │  │  Neovim           │ │  ★ Fish Shell ★   │ │    │   │
│  │  │  │                   │ │  (you are here)   │ │    │   │
│  │  │  └───────────────────┘ └───────────────────┘ │    │   │
│  │  └──────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

Fish runs inside tmux panes inside Ghostty. It is the **interactive command layer** — where you type commands, launch tools, navigate the filesystem, and manage services. Fish does NOT need to be a scripting language (we use bash/POSIX for portable scripts) or a session manager (tmux does that).

### Hardware & Toolchain (Inherited from PDE)

| Component         | Detail                                              |
| ----------------- | --------------------------------------------------- |
| **Machine**       | Apple Silicon M4 Max, macOS Tahoe 26.2              |
| **Keyboard**      | HHKB Professional Hybrid Type-S                     |
| **Terminal**      | Ghostty (GPU-accelerated, Zig-based)                |
| **Multiplexer**   | tmux (`<C-Space>` prefix)                           |
| **Shell**         | Fish 4.x (via Homebrew, Rust-based since 4.0)       |
| **Prompt**        | Starship (cross-shell, minimal config)              |
| **Plugin Manager**| Fisher (jorgebucaran/fisher)                        |
| **File Manager**  | yazi (terminal file manager)                        |
| **ls Replacement**| eza (modern ls with git + icons)                    |

### Fish Version Awareness (4.x)

Fish 4.0 (Feb 2025) rewrote the core in Rust. Key changes relevant to config:
- New `bind` key notation (`bind ctrl-right` instead of `bind \e\[1\;5C`)
- `fish_should_add_to_history` function for history filtering
- `qmark-noglob` enabled by default (`?` is no longer a glob character)
- OSC 133 prompt marking built-in (terminal integration)
- Catppuccin themes shipped built-in (4.3+)
- Universal variables moved out of the way by default (4.3+)

**Target:** Fish 4.1+ stable. Write config that works on 4.1 through 4.4.

---

## ARTICLE II — DIRECTORY ARCHITECTURE

### The Canonical Structure

```
~/.config/fish/
├── config.fish                    # Entry point: env → interactive setup → done
├── fish_plugins                   # Fisher plugin manifest (committed to git)
├── fish_variables                 # Universal variables (DO NOT edit manually)
│
├── conf.d/                        # Startup snippets (sourced BEFORE config.fish)
│   ├── fzf.fish                   # ← Fisher-managed (plugin init)
│   ├── sponge.fish                # ← Fisher-managed
│   └── z.fish                     # ← Fisher-managed
│
├── completions/                   # Tab completion definitions (autoloaded by name)
│   ├── fisher.fish                # ← Fisher-managed
│   └── (custom completions)       # ← One file per command name
│
├── functions/                     # Autoloaded functions (Fisher-managed + overrides)
│   ├── fisher.fish                # ← Fisher-managed
│   ├── (Fisher plugin functions)  # ← Fisher-managed (fzf, sponge, z, etc.)
│   └── (user overrides)           # ← e.g., yazi.fish wrapper
│
├── internal/                      # ★ USER FUNCTIONS — domain-organized ★
│   ├── brew/                      # Homebrew convenience
│   │   └── bu.fish
│   ├── eza/                       # eza theme management
│   │   └── set-eza-theme.fish
│   ├── nvim/                      # Neovim aliases/wrappers
│   │   ├── v.fish
│   │   └── vim.fish
│   ├── skhd/                      # skhd service management
│   │   ├── sk.fish
│   │   └── skr.fish
│   ├── spring-boot/               # Spring Boot dev workflow
│   │   ├── freeport.fish
│   │   ├── sbr.fish
│   │   ├── sbt.fish
│   │   ├── sr.fish
│   │   └── st.fish
│   ├── tmux/                      # tmux convenience
│   │   ├── t.fish
│   │   ├── tK.fish
│   │   └── tn.fish
│   ├── yabai/                     # yabai service + profile management
│   │   ├── yk.fish
│   │   ├── yp.fish
│   │   ├── yr.fish
│   │   └── ys.fish
│   └── yazi/                      # yazi wrapper
│       └── lf.fish
│
└── themes/                        # Fish color themes (sourced by config.fish)
    ├── kanagawa.fish
    └── (others)
```

### The `internal/` Decision — Domain-Organized Functions

**Why:** Fish's native `functions/` directory is flat — no subdirectories. Fisher plugins dump their files there, creating a mess of `_fzf_*.fish`, `__z*.fish`, and `_sponge_*.fish` mixed with user code. The `internal/` pattern gives us:

- **Visual grouping by domain** — `internal/yabai/` contains all yabai functions
- **Clean separation from Fisher** — Fisher owns `functions/`, we own `internal/`
- **Instant comprehension** — `ls internal/` shows every domain at a glance

**The tradeoff:** Fish doesn't autoload from subdirectories. We must explicitly register `internal/` subdirectories in `fish_function_path`. This is a **conscious architectural decision**, not a hack — we accept the one-time registration cost for permanent organizational clarity.

**Registration pattern (in config.fish):**

```fish
# ── Internal function paths (domain-organized) ──────────────
# Fish only autoloads from flat directories in fish_function_path.
# We add each internal/ subdirectory explicitly. This is intentional.
for dir in $HOME/.config/fish/internal/*/
    if not contains -- $dir $fish_function_path
        set -g fish_function_path $dir $fish_function_path
    end
end
```

**Rules for `internal/`:**
1. One function per file, filename = function name (Fish autoload requirement)
2. Each file contains ONLY the function definition — no side effects, no global state
3. Domain directories are created when the first function in that domain is written
4. No nesting beyond one level (`internal/domain/function.fish` — never deeper)
5. Every function has `--description` (Fish's native doc mechanism)
6. Functions that need completions put them in `completions/<function_name>.fish`

---

## ARTICLE III — CONFIGURATION PRINCIPLES

### Principle 1: config.fish Is Thin

`config.fish` is the entry point. It should be **short and scannable** — environment variables, path setup, internal function registration, interactive-only setup, and nothing else. No inline function definitions. No walls of aliases.

Target: Under 80 lines. If it's growing past that, something belongs in a function file, a conf.d snippet, or an `internal/` function.

### Principle 2: config.fish Load Order

```fish
# ~/.config/fish/config.fish
# ─── Fish Shell Configuration ───────────────────────────────
# Load order:
#   1. conf.d/*.fish         (sourced by Fish BEFORE this file)
#   2. This file (config.fish)
#      a. Global environment  (all shells — interactive and non-interactive)
#      b. Internal paths      (register internal/ function directories)
#      c. Interactive setup   (prompt, theme, aliases, tool init — interactive only)

# ── 1. Global Environment (runs in ALL shells) ──────────────
# ... env vars, PATH additions ...

# ── 2. Internal Function Paths ──────────────────────────────
# ... fish_function_path registration ...

# ── 3. Interactive Only ─────────────────────────────────────
if status is-interactive
    # ... prompt, theme, tool init, aliases, abbrs ...
end
```

### Principle 3: conf.d/ Is Fisher's Territory

The `conf.d/` directory is primarily managed by Fisher for plugin initialization. Do NOT put custom config snippets there unless:
- They are event handlers (which can't be autoloaded)
- They need to run BEFORE config.fish (conf.d loads first)

For everything else, use `config.fish` or `internal/` functions.

### Principle 4: functions/ Is Fisher's Territory

The canonical `functions/` directory is where Fisher installs plugin functions. User functions go in `internal/`. The only user files in `functions/` should be:
- Overrides of Fish built-in functions (e.g., custom `fish_greeting`)
- Wrappers that must live in the default function path (rare)

### Principle 5: Aliases vs. Abbreviations vs. Functions

Fish has three mechanisms. Use the right one:

| Mechanism | Use When | Example |
| --------- | -------- | ------- |
| **`abbr`** | Simple command shortcuts you want to SEE expanded before execution | `abbr .. "cd .."` |
| **`alias`** | Command wrappers that should be invisible (no expansion) | `alias ls="eza --icons"` |
| **`function`** | Anything with logic, arguments, or flags | `sbr`, `yr`, `freeport` |

**Rule of thumb:**
- If it's one command with no logic → `alias` or `abbr`
- If it takes arguments or has conditionals → `function` in `internal/`
- Prefer `abbr` over `alias` for navigation shortcuts (you see what you're about to run)

### Principle 6: Universal Variables — Set Once, Never in config.fish

Universal variables (`set -U`) persist across all sessions and restarts. They are stored in `fish_variables`. **Never set universal variables in config.fish** — they'll grow longer with each shell instance.

Set them once at the command line:
```fish
# Run ONCE interactively, not in config.fish:
set -U fish_greeting ""
```

In config.fish, use `set -gx` (global exported) for environment variables.

### Principle 7: No Portable Scripting in Fish

Fish is for interactive use. System scripts, CI scripts, and anything that needs to run on machines without Fish should be written in bash/POSIX sh. Don't fight Fish's non-POSIX syntax for portability — embrace it for ergonomics.

### Principle 8: Comments Document WHY, Not WHAT

```fish
# ✗ BAD
set -gx EDITOR nvim  # set editor to nvim

# ✓ GOOD
set -gx EDITOR nvim  # Neovim is the PDE's brain — must be default everywhere
```

### Principle 9: Functions Are Self-Documenting

Every function uses Fish's `--description` flag and includes a header comment:

```fish
# path: ~/.config/fish/internal/yabai/yr.fish
# description: Restart yabai + skhd and apply a layout profile.
# usage: yr [-P bsp|stack|float] [--status]
# date: 2026-02-08

function yr --description "yabai + skhd: restart + apply profile"
    # ...
end
```

### Principle 10: No Dead Code

If a function, alias, or config line isn't actively used, remove it. Don't comment it out "for later." Git remembers.

---

## ARTICLE IV — ENVIRONMENT STANDARDS

### PATH Management

```fish
# Use fish_add_path — idempotent, no duplicates, no growth
fish_add_path /opt/homebrew/bin
fish_add_path $HOME/.local/bin
```

**Never** do `set -gx PATH something $PATH` in config.fish — it grows on every shell start. `fish_add_path` is idempotent.

### Tool Initialization Pattern

Version managers and tool initializers follow a consistent pattern:

```fish
# ── Tool Init (interactive only) ────────────────────────────
if status is-interactive

    # Starship prompt
    starship init fish | source

    # jenv (Java version manager)
    if test -d $HOME/.jenv
        fish_add_path $HOME/.jenv/bin
        jenv init - | source
    end

    # fnm (Node version manager)
    if type -q fnm
        fnm env --use-on-cd | source
    end

    # pyenv (Python version manager)
    if type -q pyenv
        set -gx PYENV_ROOT $HOME/.pyenv
        fish_add_path $PYENV_ROOT/bin
        pyenv init - | source
    end

    # direnv (per-directory env)
    if type -q direnv
        direnv hook fish | source
    end
end
```

**Pattern:** Guard with `type -q` or `test -d` — don't assume tools are installed. This prevents errors on fresh machines or CI environments.

### Required Environment Variables

```fish
# ── Global Environment ──────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx STARSHIP_CONFIG $HOME/.config/starship/starship.toml
set -gx EZA_CONFIG_DIR $HOME/.config/eza
```

---

## ARTICLE V — FUNCTION STANDARDS

### Function File Template

```fish
# path: ~/.config/fish/internal/<domain>/<name>.fish
# description: <one-line description>
# usage: <name> [flags] [args]
# date: <creation date>
# changelog: <date> | <change> | ROLLBACK: <instructions>

function <name> --description '<one-line description>'
    # ... implementation ...
end
```

### Function Naming Conventions

| Domain | Prefix Pattern | Examples |
| ------ | -------------- | -------- |
| yabai  | `y*`           | `yr`, `yp`, `ys`, `yk` |
| skhd   | `sk*`          | `sk`, `skr` |
| tmux   | `t*`           | `t`, `tn`, `tK` |
| nvim   | (bare)         | `v`, `vim` |
| spring | `sb*` / `sr`   | `sbr`, `sbt`, `sr`, `st` |
| brew   | `bu`           | `bu` |

Function names are short — these are typed hundreds of times a day. The domain directory provides context; the name provides speed.

### Completion Files

Functions with flags/arguments should have completions:

```fish
# path: ~/.config/fish/completions/<name>.fish
complete -c <name> -s p -l port -d "Server port"
complete -c <name> -s P -l profile -xa "dev test prod" -d "Spring profile"
```

### Functions That Wrap Commands

Use `--wraps` for proper completion inheritance:

```fish
function v --wraps=nvim --description 'v as Neovim'
    nvim $argv
end
complete -c v -w nvim
```

---

## ARTICLE VI — PLUGIN MANAGEMENT (Fisher)

### Fisher Principles

Fisher is the plugin manager. It's minimal, pure-Fish, and uses a simple `fish_plugins` file.

**Rules:**
1. `fish_plugins` is committed to git (it's the lockfile equivalent)
2. `fish_variables` is NOT committed (contains machine-specific state)
3. Fisher-managed files in `functions/`, `completions/`, `conf.d/` are NOT manually edited
4. Plugin count stays minimal — each plugin must justify its existence

### Current Plugin Stack

```
jorgebucaran/fisher          # Plugin manager itself
jethrokuan/z                 # Directory jumping (frecency-based cd)
meaningful-ooo/sponge        # Clean failed commands from history
patrickf1/fzf.fish           # fzf integration (Ctrl+R history, Ctrl+F files, etc.)
```

### Plugin Evaluation Criteria

Before adding a plugin, ask:
1. Can Fish do this natively? (Fish's built-in features are extensive)
2. Can a simple function in `internal/` handle this?
3. Is it actively maintained? (< 12 months since last commit)
4. Does it conflict with existing plugins or config?
5. What does it add to `functions/` and `conf.d/`? (pollution cost)

---

## ARTICLE VII — ALIASES & ABBREVIATIONS

### eza Aliases (ls replacement)

```fish
alias ls="eza --group-directories-first --color=always --icons"
alias la="eza -a --group-directories-first --color=always --icons"
alias ll="eza -l -a -h --no-filesize --group-directories-first --color=always --icons"
alias ld="eza -a -l --header --created --accessed --changed --no-user --no-filesize --time-style=relative --icons"
alias lr="eza -R -a -h --group-directories-first --color=always --icons"
alias lt="eza -T --color=always --icons"
```

### Navigation Abbreviations

```fish
abbr .. "cd .."
abbr ... "cd ../.."
```

### Rule: Aliases and Abbreviations Live in config.fish

They are short, they are interactive-only, and they don't warrant separate files. Keep them in the `if status is-interactive` block, grouped by domain with section headers.

---

## ARTICLE VIII — THEMES & APPEARANCE

### Theme Strategy

Fish color themes are sourced in the interactive block. The PDE uses kanagawa aesthetics across all tools (Neovim, Ghostty, tmux, Fish).

```fish
# In config.fish, interactive block:
source ~/.config/fish/themes/kanagawa.fish
```

### Fish Greeting

Disabled. Silence is golden.

```fish
# Set ONCE interactively (universal variable):
set -U fish_greeting ""
```

### Starship Prompt

Starship handles the prompt. Fish's built-in `fish_prompt` is NOT customized — Starship overrides it via `starship init fish | source`.

Starship config lives at `~/.config/starship/starship.toml` — a separate config in the PDE.

---

## ARTICLE IX — HARD RULES

### Rule 1: NO INLINE FUNCTION DEFINITIONS IN config.fish

```fish
# ✗ BANNED — function defined inline in config.fish
function bu --description 'brew update'
    brew update && brew upgrade && brew cleanup
end

# ✓ REQUIRED — function in internal/brew/bu.fish, autoloaded
```

### Rule 2: ONE FUNCTION PER FILE, FILENAME = FUNCTION NAME

Fish autoloading requires this. `yr.fish` must define `function yr`. No exceptions.

### Rule 3: EVERY FUNCTION HAS --description

No exceptions. This is Fish's native documentation mechanism and shows up in `functions` and `type` output.

### Rule 4: NO UNIVERSAL VARIABLES IN config.fish

Set them once at the command line with `set -U`. Never in config.fish.

### Rule 5: fish_plugins IS COMMITTED, fish_variables IS NOT

`fish_plugins` = reproducible plugin list (like `lazy-lock.json`).
`fish_variables` = machine-local state (like `.env` files).

### Rule 6: GUARD TOOL INITIALIZATION

```fish
# ✓ Always guard — don't assume tools exist
if type -q fnm
    fnm env --use-on-cd | source
end

# ✗ Never assume
fnm env --use-on-cd | source  # Crashes if fnm not installed
```

### Rule 7: NO POSIX-ISMs

Write idiomatic Fish. No `&&` chains (use `; and`), no `$(...)` (use `(...)`), no `export` (use `set -gx`). Fish is not bash — don't pretend it is.

**Note:** Fish 3.4+ does support `&&` and `||` as syntactic sugar. Using them is acceptable for simple chains like `brew update && brew upgrade`. The principle is: don't import bash *patterns* — use Fish idioms where Fish has a better way.

### Rule 8: USE fish_add_path, NOT set PATH

```fish
# ✓ Idempotent, safe in config.fish
fish_add_path /opt/homebrew/bin

# ✗ Grows PATH on every shell start
set -gx PATH /opt/homebrew/bin $PATH
```

---

## ARTICLE X — CURRENT PRIORITY STACK

### What Exists (Post-Nuke, Rebuilt)

| Domain       | Functions | Status |
| ------------ | --------- | ------ |
| yabai        | `yr`, `yp`, `ys`, `yk` | ✅ Rebuilt |
| skhd         | `sk`, `skr` | ✅ Rebuilt |

### What Needs Rebuilding

| Domain       | Functions | Priority |
| ------------ | --------- | -------- |
| config.fish  | (the file itself) | 🔴 Now |
| nvim         | `v`, `vim` | 🔴 Now |
| tmux         | `t`, `tn`, `tK` | 🔴 Now |
| brew         | `bu` | 🟡 Soon |
| eza          | `set-eza-theme` | 🟡 Soon |
| spring-boot  | `sbr`, `sbt`, `sr`, `st`, `freeport` | 🟡 When dev resumes |
| yazi         | `lf` | 🟡 Soon |
| themes       | kanagawa.fish | 🟡 Soon |
| completions  | (for flagged functions) | 🔵 Later |
| fish_plugins | (audit current list) | 🟡 Soon |

---

## ARTICLE XI — LLM RESPONSE PROTOCOL

### First Response Checklist

When starting a NEW conversation about Fish config:

1. Ask for current `config.fish` contents
2. Ask for `fish_plugins` contents
3. Ask for `ls internal/` output
4. Ask what daily workflow looks like currently
5. THEN propose — never prescribe blind

### Code Generation Rules

1. **Complete files only** — no snippets, no `# ... rest of file`
2. **File path as first comment** — `# path: ~/.config/fish/internal/tmux/t.fish`
3. **CHANGELOG on modified files** — `# changelog: 2026-02-09 | Added --status flag | ROLLBACK: Remove lines 15-30`
4. **`--description` on every function**
5. **`--wraps` on command wrappers** (for completion inheritance)
6. **Guard tool availability** with `type -q` or `test -d`
7. Modern Fish 4.x idioms (new bind notation, fish_add_path)

### Function Consultation

Before writing or modifying a function:
- Does Fish do this natively? (many things are built-in)
- Would an alias or abbreviation be simpler?
- Does it conflict with an existing function name?
- Does it need a completion file?
- Is the function name short enough for daily typing?

### Code Review Protocol

1. Call out inline function definitions in config.fish (Rule 1 violation)
2. Call out functions without `--description` (Rule 3 violation)
3. Call out universal variable assignments in config.fish (Rule 4 violation)
4. Call out unguarded tool initialization (Rule 6 violation)
5. Call out dead code, commented-out blocks, unused functions
6. Call out `set PATH` instead of `fish_add_path` (Rule 8 violation)
7. **Suggest removals** — leaner is better

### Pre-Merge Checklist

```
[ ] config.fish under 80 lines?
[ ] No inline function definitions in config.fish?
[ ] Every function has --description?
[ ] Every wrapper function has --wraps?
[ ] No universal variable assignments in config.fish?
[ ] All tool init guarded with type -q or test -d?
[ ] fish_plugins committed, fish_variables not?
[ ] internal/ directories are one level deep only?
[ ] One function per file, filename = function name?
[ ] No dead code or commented-out blocks?
```

---

## ARTICLE XII — SAFETY & RECOVERABILITY

### Transition Protocol

When renaming or removing a function:
1. Keep the old function as a wrapper that calls the new one + warns
2. After 7 days, remove the old function
3. Every CHANGELOG includes ROLLBACK instructions

### Validation

```fish
# Check Fish config syntax
fish -n ~/.config/fish/config.fish

# Check a function file syntax
fish -n ~/.config/fish/internal/yabai/yr.fish

# List all loaded functions (verify internal/ registration)
functions | head -20

# Verify no inline functions leaked into config.fish
grep -n "^function " ~/.config/fish/config.fish
# Should return EMPTY

# Check startup time (should be near-instant)
time fish -c exit
```

---

## ARTICLE XIII — PHILOSOPHICAL REMINDERS

> Fish is the fastest path between thought and execution. Every alias, every function, every keybinding exists to reduce the gap between "I want to do X" and X being done.

> The shell should be invisible. If you're thinking about your shell, something is wrong. Configure it once, then forget it exists.

> Less is more. Four plugins. A thin config.fish. Domain-organized functions. That's it. The shell that requires the least configuration is the shell that gets out of your way the fastest.

> `internal/` is the innovation. Fish says "flat functions directory." We say "domain-organized, visually grouped, immediately comprehensible." We accept the `fish_function_path` registration cost for permanent clarity. This is a deliberate tradeoff, not a hack.

> The PDE breathes as one. Fish serves Neovim, tmux, yabai, and every other tool. `v` opens Neovim. `t` opens tmux. `yr` restarts yabai. The shell is the glue.

---

_Version 1.0 | February 2026 | Fish 4.1+ | Fisher | macOS Tahoe (M4 Max)_
_Part of the PDE rebuild — every tool earns its place._

<!-- CHANGELOG v1.0 (2026-02-09):
  - Initial constitution
  - Established internal/ domain-organized function architecture
  - Defined config.fish load order and thinness principle
  - Established Fisher as plugin manager with 4-plugin stack
  - Defined alias vs abbreviation vs function decision framework
  - Established 10 hard rules
  - Defined LLM response protocol
  ROLLBACK: This is v1.0, no previous version exists -->
