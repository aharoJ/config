### Neovim `vim.*` Cheat-Sheet

- `vim.b` → **Buffer variables** (per-buffer scope, e.g., `vim.b.my_var`)  
- `vim.t` → **Tabpage variables** (per tab scope)  
- `vim.w` → **Window variables** (per window scope)  
- `vim.g` → **Global variables** (shared across Neovim session)  

- `vim.bo` → **Buffer options** (like `shiftwidth`, `tabstop`, `expandtab`)  
- `vim.wo` → **Window options** (like `number`, `relativenumber`, `cursorline`)  
- `vim.to` → **Tabpage options** (rarely used, but per tab settings)  

- `vim.o`  → **Global options** (like `ignorecase`, `wrap`, `clipboard`)  
- `vim.opt` → **Modern API for options** (preferred over `vim.o`, chainable and safe)  
- `vim.opt_local` → **Local options** (applies only to the current buffer/window/tab)  

---

For example, with your `:ls` output:

```
  1 h   "."
  3 h + "~/.config/nvim/lua/core/keymaps.lua"
 11 #h  "~/.config/nvim/lua/core/mute.lua"
 15 %a  "~/.config/nvim/lua/core/globals.lua"
```

If you want to switch to buffer **3**:

```vim
:b 3
```

If you want to switch to buffer **11**:

```vim
:b 11
```
