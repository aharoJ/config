

``lua
keys = {
        -- ── Telescope Builtins (bindable) ─────────────────────────
        -- File Pickers:
        --   find_files()                → Search files by name
        --   git_files()                 → Search git-tracked files
        --   live_grep()                 → Search file contents (ripgrep)
        --   grep_string()              → Grep word under cursor
        --
        -- Buffer/Navigation Pickers:
        --   buffers()                   → Open buffers
        --   current_buffer_fuzzy_find() → Fuzzy search current buffer
        --   oldfiles()                  → Recently opened files
        --   marks()                     → Vim marks
        --   jumplist()                  → Jump list entries
        --   quickfix()                  → Quickfix list
        --   loclist()                   → Location list
        --   registers()                 → Vim registers
        --
        -- LSP Pickers:
        --   lsp_references()            → References (telescope UI for grr)
        --   lsp_definitions()           → Definitions (telescope UI for gd)
        --   lsp_type_definitions()      → Type definitions (telescope UI for grt)
        --   lsp_implementations()       → Implementations (telescope UI for gri)
        --   lsp_document_symbols()      → Document symbols (telescope UI for gO)
        --   lsp_workspace_symbols()     → Workspace symbols
        --   lsp_dynamic_workspace_symbols() → Dynamic workspace symbols
        --   diagnostics()               → Diagnostics (telescope UI)
        --
        -- Git Pickers:
        --   git_commits()               → Git log
        --   git_bcommits()              → Git log for current buffer
        --   git_branches()              → Git branches
        --   git_status()                → Git status
        --   git_stash()                 → Git stash
        --
        -- Vim Pickers:
        --   commands()                  → Available ex commands
        --   keymaps()                   → All keymaps
        --   help_tags()                 → Help tags
        --   man_pages()                 → Man pages
        --   highlights()                → Highlight groups
        --   colorscheme()               → Colorschemes
        --   filetypes()                 → Filetypes
        --   autocommands()              → Autocommands
        --   vim_options()               → Vim options
        --   spell_suggest()             → Spelling suggestions
        --   resume()                    → Re-open last picker
        --   pickers()                   → List previous pickers

        { "<leader>gf", function() require("telescope.builtin").find_files(find_files_opts) end, desc = "[get] file", },
        { "<leader>gb", function() require("telescope.builtin").buffers(buffers_opts) end, desc = "[get] buffer", },
        { "<leader>g,", function() require("telescope.builtin").current_buffer_fuzzy_find(current_buffer_fuzzy_find_opts) end, desc = "[get] ," },
        { "<leader>gw", function() require("telescope.builtin").grep_string(grep_string_opts) end, desc = "[get] word" },
        { "<leader>g.", function() require("telescope.builtin").live_grep(live_grep_opts) end, desc = "[get] grep" },
    },
```
