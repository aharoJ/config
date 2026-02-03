-- path: nvim/lua/plugins/core/telescope.lua
-- Description: Fuzzy finder — the nerve center of file/code/symbol navigation.
--              Telescope is the single most-used plugin. Every binding here is
--              HHKB Tier 1 (Space + single key) or Tier 2 (Space + chord).
--
-- PHILOSOPHY: Start with the 5 pickers you use 50 times a day.
--             Everything else is commented out, documented, and ready to enable.
--             Uncomment a picker → it lazy-loads on that keymap. Zero cost until used.
--
-- CHANGELOG: 2026-02-03 | Initial creation — constitution-compliant | ROLLBACK: Delete file

return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- WHY: Native FZF algorithm compiled to C. 10-100x faster sorting on large repos.
    -- Without this, typing in a 50k-file monorepo feels sluggish.
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },

  -- ── Lazy Loading ──────────────────────────────────────────────────────
  -- Telescope loads on first keymap hit OR :Telescope command.
  -- Zero startup cost — it's not in your 50ms budget until you need it.
  cmd = "Telescope",

  -- ── Keymaps ───────────────────────────────────────────────────────────
  -- Convention: <leader>f = Find namespace (Article VI)
  -- HHKB: Space (thumb) + single key = Tier 1, fastest possible binding.
  --
  -- ACTIVE pickers are uncommented. AVAILABLE pickers are commented with
  -- their desc so you know exactly what you're enabling when you uncomment.
  -- Each commented block includes the HHKB comfort tier.
  keys = {

    -- ── TIER 1: Daily Drivers (uncommented = active) ────────────────
    -- These are the 5 pickers you'll hit 50+ times per day.

    -- Find files by name. Your most frequent action.
    -- WHY function wrapper: allows passing opts dynamically in the future.
    {
      "<leader>ff",
      function() require("telescope.builtin").find_files() end,
      desc = "Find files",
    },

    -- Full-text search across entire project. Second most frequent.
    {
      "<leader>fg",
      function() require("telescope.builtin").live_grep() end,
      desc = "Live grep (project-wide)",
    },

    -- Switch between open buffers. Third most frequent.
    {
      "<leader>fb",
      function()
        require("telescope.builtin").buffers({
          sort_mru = true,                -- Most recently used first
          ignore_current_buffer = true,   -- Don't show the buffer you're already in
        })
      end,
      desc = "Find buffers (MRU order)",
    },

    -- Fuzzy search inside current file. Replaces Ctrl-F muscle memory.
    {
      "<leader>/",
      function() require("telescope.builtin").current_buffer_fuzzy_find() end,
      desc = "Fuzzy search in current buffer",
    },

    -- Resume last picker exactly where you left off (selections preserved).
    -- WHY: You grep, find 3 results, accidentally close — this gets you back.
    {
      "<leader>fr",
      function() require("telescope.builtin").resume() end,
      desc = "Resume last picker",
    },

    -- ── TIER 1: Grep Variants ───────────────────────────────────────
    -- Grep the word under cursor. Visual mode greps the selection.
    {
      "<leader>fw",
      function() require("telescope.builtin").grep_string() end,
      mode = { "n", "v" },
      desc = "Grep word under cursor",
    },

    -- ── TIER 2: File Discovery ──────────────────────────────────────

    -- Recently opened files across all sessions.
    {
      "<leader>fo",
      function() require("telescope.builtin").oldfiles() end,
      desc = "Find recent files (oldfiles)",
    },

    -- -- Find files including hidden (dotfiles). Useful for config work.
    -- {
    --   "<leader>fF",
    --   function() require("telescope.builtin").find_files({ hidden = true, no_ignore = true }) end,
    --   desc = "Find ALL files (incl. hidden/ignored)",
    -- },

    -- -- Git-tracked files only (faster than find_files in git repos).
    -- {
    --   "<leader>fG",
    --   function() require("telescope.builtin").git_files() end,
    --   desc = "Find git files",
    -- },

    -- ── TIER 2: Vim Internals ───────────────────────────────────────

    -- Search help tags. Essential for learning Neovim.
    {
      "<leader>fh",
      function() require("telescope.builtin").help_tags() end,
      desc = "Find help tags",
    },

    -- -- Search all keymaps. Great for discovering what's bound where.
    -- {
    --   "<leader>fk",
    --   function() require("telescope.builtin").keymaps() end,
    --   desc = "Find keymaps",
    -- },

    -- -- Search vim commands (plugin + user commands).
    -- {
    --   "<leader>fc",
    --   function() require("telescope.builtin").commands() end,
    --   desc = "Find commands",
    -- },

    -- -- Search vim marks.
    -- {
    --   "<leader>fm",
    --   function() require("telescope.builtin").marks() end,
    --   desc = "Find marks",
    -- },

    -- -- Search vim registers. See what's in your clipboard/yank history.
    -- {
    --   "<leader>f\"",
    --   function() require("telescope.builtin").registers() end,
    --   desc = "Find registers",
    -- },

    -- -- Search highlights. Useful when tweaking colorscheme.
    -- {
    --   "<leader>fH",
    --   function() require("telescope.builtin").highlights() end,
    --   desc = "Find highlights",
    -- },

    -- -- Command history. Re-run recent ex commands.
    -- {
    --   "<leader>f:",
    --   function() require("telescope.builtin").command_history() end,
    --   desc = "Find command history",
    -- },

    -- -- Search history. Re-run recent searches.
    -- {
    --   "<leader>f/",
    --   function() require("telescope.builtin").search_history() end,
    --   desc = "Find search history",
    -- },

    -- -- Autocommands. Debug what's running on events.
    -- {
    --   "<leader>fa",
    --   function() require("telescope.builtin").autocommands() end,
    --   desc = "Find autocommands",
    -- },

    -- -- Vim options. Quickly toggle/inspect settings.
    -- {
    --   "<leader>fO",
    --   function() require("telescope.builtin").vim_options() end,
    --   desc = "Find vim options",
    -- },

    -- -- Filetypes. Set filetype for current buffer.
    -- {
    --   "<leader>ft",
    --   function() require("telescope.builtin").filetypes() end,
    --   desc = "Find filetypes",
    -- },

    -- -- Colorschemes with live preview.
    -- {
    --   "<leader>fC",
    --   function() require("telescope.builtin").colorscheme({ enable_preview = true }) end,
    --   desc = "Find colorschemes (preview)",
    -- },

    -- ── TIER 2: Navigation ──────────────────────────────────────────

    -- -- Quickfix list in telescope (better than :copen).
    -- {
    --   "<leader>fq",
    --   function() require("telescope.builtin").quickfix() end,
    --   desc = "Find quickfix items",
    -- },

    -- -- Location list in telescope.
    -- {
    --   "<leader>fl",
    --   function() require("telescope.builtin").loclist() end,
    --   desc = "Find loclist items",
    -- },

    -- -- Jumplist. Navigate your jump history.
    -- {
    --   "<leader>fj",
    --   function() require("telescope.builtin").jumplist() end,
    --   desc = "Find jumplist entries",
    -- },

    -- -- Treesitter symbols (functions, variables, classes).
    -- {
    --   "<leader>fs",
    --   function() require("telescope.builtin").treesitter() end,
    --   desc = "Find treesitter symbols",
    -- },

    -- -- Spell suggestions for word under cursor.
    -- {
    --   "<leader>fz",
    --   function() require("telescope.builtin").spell_suggest() end,
    --   desc = "Find spelling suggestions",
    -- },

    -- -- Man pages. Quick reference.
    -- {
    --   "<leader>fM",
    --   function() require("telescope.builtin").man_pages({ sections = { "ALL" } }) end,
    --   desc = "Find man pages",
    -- },

    -- ── TIER 2: Git (leader>g namespace reserved, but git pickers ──
    -- ── can also live under leader>f if you prefer one namespace) ────

    -- -- Git commits (project-wide) with diff preview.
    -- {
    --   "<leader>gc",
    --   function() require("telescope.builtin").git_commits() end,
    --   desc = "Git commits (project)",
    -- },

    -- -- Git commits for current buffer only.
    -- {
    --   "<leader>gC",
    --   function() require("telescope.builtin").git_bcommits() end,
    --   desc = "Git commits (buffer)",
    -- },

    -- -- Git branches. Checkout, track, rebase, delete.
    -- {
    --   "<leader>gb",
    --   function() require("telescope.builtin").git_branches() end,
    --   desc = "Git branches",
    -- },

    -- -- Git status. Stage/unstage files.
    -- {
    --   "<leader>gs",
    --   function() require("telescope.builtin").git_status() end,
    --   desc = "Git status",
    -- },

    -- -- Git stash list. Apply stashes.
    -- {
    --   "<leader>gS",
    --   function() require("telescope.builtin").git_stash() end,
    --   desc = "Git stash",
    -- },

    -- ── TIER 2: LSP Pickers (reserved for Phase 2+) ────────────────
    -- NOTE: These overlap with native 0.11+ LSP keymaps (grr, gri, etc.)
    -- Only uncomment if you want Telescope UI for multi-result LSP queries.

    -- -- LSP references for symbol under cursor.
    -- {
    --   "<leader>lr",
    --   function() require("telescope.builtin").lsp_references() end,
    --   desc = "LSP references",
    -- },

    -- -- LSP document symbols (current file).
    -- {
    --   "<leader>ls",
    --   function() require("telescope.builtin").lsp_document_symbols() end,
    --   desc = "LSP document symbols",
    -- },

    -- -- LSP workspace symbols (entire project).
    -- {
    --   "<leader>lS",
    --   function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end,
    --   desc = "LSP workspace symbols",
    -- },

    -- -- LSP definitions (usually just one, but Telescope handles multiples).
    -- {
    --   "<leader>ld",
    --   function() require("telescope.builtin").lsp_definitions() end,
    --   desc = "LSP definitions",
    -- },

    -- -- LSP type definitions.
    -- {
    --   "<leader>lt",
    --   function() require("telescope.builtin").lsp_type_definitions() end,
    --   desc = "LSP type definitions",
    -- },

    -- -- LSP implementations.
    -- {
    --   "<leader>li",
    --   function() require("telescope.builtin").lsp_implementations() end,
    --   desc = "LSP implementations",
    -- },

    -- -- LSP incoming calls.
    -- {
    --   "<leader>lI",
    --   function() require("telescope.builtin").lsp_incoming_calls() end,
    --   desc = "LSP incoming calls",
    -- },

    -- -- LSP outgoing calls.
    -- {
    --   "<leader>lO",
    --   function() require("telescope.builtin").lsp_outgoing_calls() end,
    --   desc = "LSP outgoing calls",
    -- },

    -- -- Diagnostics (all buffers).
    -- {
    --   "<leader>fd",
    --   function() require("telescope.builtin").diagnostics() end,
    --   desc = "Find diagnostics (all buffers)",
    -- },

    -- -- Diagnostics (current buffer only).
    -- {
    --   "<leader>fD",
    --   function() require("telescope.builtin").diagnostics({ bufnr = 0 }) end,
    --   desc = "Find diagnostics (current buffer)",
    -- },

    -- ── META: Telescope about Telescope ─────────────────────────────

    -- -- Browse all builtin pickers. The "I forgot the keymap" escape hatch.
    -- {
    --   "<leader>fP",
    --   function() require("telescope.builtin").builtin() end,
    --   desc = "Find telescope pickers (meta)",
    -- },

    -- -- Previous cached pickers. Navigate your picker history.
    -- {
    --   "<leader>fp",
    --   function() require("telescope.builtin").pickers() end,
    --   desc = "Find previous pickers",
    -- },
  },

  -- ── Configuration ─────────────────────────────────────────────────────
  opts = {
    defaults = {

      -- ── Appearance ──────────────────────────────────────────────────
      -- WHY rounded: Matches vim.o.winborder from core/options.lua (0.11+).
      -- Consistent border language across every floating window in the editor.
      borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },

      -- WHY these prefixes: Clean, readable, no-fuss.
      -- Nerd Font glyphs go in lib/icons.lua when that exists — swap these then.
      prompt_prefix = " > ",
      selection_caret = " > ",
      entry_prefix = "   ",
      multi_icon = " + ",

      -- WHY dynamic: Shows the actual filename in preview title bar.
      dynamic_preview_title = true,

      -- WHY filename_first: When scanning results, the filename matters more
      -- than the path. Brain processes "Controller.java" faster than
      -- "src/main/java/com/app/controller/Controller.java".
      path_display = { "filename_first" },

      -- WHY ascending + top: Best matches at the TOP of results, prompt at top.
      -- Eyes stay in one place — scan down from the top match.
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,     -- Slightly more than half for preview
          width = 0.87,             -- Leave some breathing room on sides
          height = 0.80,
        },
        vertical = {
          prompt_position = "top",
          mirror = false,
          width = 0.87,
          height = 0.90,
          preview_height = 0.5,
        },
      },

      -- ── Behavior ────────────────────────────────────────────────────
      -- WHY: Regex patterns for files that should NEVER appear in results.
      -- These are noise in every picker — build artifacts, deps, VCS internals.
      file_ignore_patterns = {
        "%.git/",
        "node_modules/",
        "%.class$",
        "target/",
        "build/",
        "dist/",
        "%.lock$",
        "__pycache__/",
        "%.pyc$",
      },

      -- WHY follow: Opening a result should scroll so the match is visible,
      -- not jump to the cursor position from the previous visit.
      selection_strategy = "reset",

      -- WHY cycle: When you hit the bottom of results, wrap to top.
      scroll_strategy = "cycle",

      -- ── Ripgrep Arguments ───────────────────────────────────────────
      -- WHY --smart-case: matches your core/options.lua ignorecase+smartcase.
      -- WHY --hidden: search dotfiles too (like .env, .eslintrc).
      -- WHY --glob !.git/: but exclude .git directory itself.
      vimgrep_arguments = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--hidden",
        "--glob=!.git/",
      },

      -- ── Mappings ────────────────────────────────────────────────────
      -- WHY custom mappings: Telescope's defaults use <C-u>/<C-d> for preview
      -- scroll, which conflicts with your core/keymaps.lua half-page jump.
      -- These mappings are INTERNAL to the Telescope picker window only.
      mappings = {
        i = {
          -- Navigation within results (HHKB: Ctrl is home row)
          ["<C-n>"] = "move_selection_next",
          ["<C-p>"] = "move_selection_previous",

          -- Preview scrolling (HHKB: Ctrl + f/b like readline)
          ["<C-f>"] = "preview_scrolling_down",
          ["<C-b>"] = "preview_scrolling_up",

          -- Open in splits (Telescope defaults, kept for muscle memory)
          ["<C-x>"] = "select_horizontal",
          ["<C-v>"] = "select_vertical",
          ["<C-t>"] = "select_tab",

          -- Send results to quickfix (power move for multi-file refactoring)
          ["<C-q>"] = "smart_send_to_qflist",
          ["<M-q>"] = "smart_add_to_qflist",

          -- Toggle preview visibility (HHKB: Meta is thumb-accessible)
          -- <M-p> toggle_preview is set in config() below (needs require at runtime)

          -- History navigation
          ["<C-j>"] = "cycle_history_next",
          ["<C-k>"] = "cycle_history_prev",

          -- Close with Escape (single press in insert mode)
          ["<Esc>"] = "close",
        },
        n = {
          -- Normal mode: vim-native navigation
          ["j"] = "move_selection_next",
          ["k"] = "move_selection_previous",
          ["H"] = "move_to_top",
          ["M"] = "move_to_middle",
          ["L"] = "move_to_bottom",
          ["gg"] = "move_to_top",
          ["G"] = "move_to_bottom",

          ["<C-f>"] = "preview_scrolling_down",
          ["<C-b>"] = "preview_scrolling_up",

          ["<C-q>"] = "smart_send_to_qflist",

          ["q"] = "close",
          ["<Esc>"] = "close",

          -- WHY ?: Shows all available mappings (like which-key for telescope)
          ["?"] = "which_key",
        },
      },
    },

    -- ── Per-Picker Overrides ────────────────────────────────────────────
    -- WHY: Some pickers benefit from different layouts or options.
    -- These override `defaults` for their specific picker only.
    pickers = {
      find_files = {
        -- WHY hidden + no_ignore false: Find dotfiles but still respect gitignore.
        hidden = true,
        -- WHY fd: Faster than find, respects .gitignore by default.
        -- fd is installed via Homebrew on your M4 Max.
        find_command = { "fd", "--type", "f", "--strip-cwd-prefix", "--hidden", "--exclude", ".git" },
      },

      buffers = {
        -- WHY dropdown: Buffer switching is a quick, small action.
        -- Full horizontal layout is overkill for 5-15 buffers.
        theme = "dropdown",
        previewer = false,              -- You know what's in your buffers
        sort_mru = true,                -- Most recently used first
        ignore_current_buffer = true,   -- Don't show buffer you're already in
      },

      current_buffer_fuzzy_find = {
        -- WHY dropdown: Searching within a file is a focused, narrow action.
        theme = "dropdown",
        previewer = false,
      },

      oldfiles = {
        -- WHY cwd_only false: Recent files from ANY project, not just current.
        -- You jump between repos — this helps you find what you were editing.
        cwd_only = false,
      },

      live_grep = {
        -- WHY additional_args: Include hidden files in grep too.
        additional_args = function()
          return { "--hidden", "--glob=!.git/" }
        end,
      },

      -- -- Uncomment as you enable LSP pickers:
      -- lsp_references = { show_line = false },
      -- lsp_definitions = { show_line = false },
      -- lsp_implementations = { show_line = false },

      -- -- Uncomment for git pickers with custom options:
      -- git_commits = { },
      -- git_status = { },
    },

    -- ── Extensions ──────────────────────────────────────────────────────
    extensions = {
      fzf = {
        fuzzy = true,                   -- Enable fuzzy matching
        override_generic_sorter = true, -- Replace Telescope's generic sorter
        override_file_sorter = true,    -- Replace Telescope's file sorter
        case_mode = "smart_case",       -- Match core/options.lua behavior
      },
    },
  },

  -- ── Imperative Setup ──────────────────────────────────────────────────
  -- WHY config instead of just opts: We need to call load_extension() after
  -- telescope.setup(). This is imperative logic that opts alone can't express.
  config = function(_, opts)
    local telescope = require("telescope")

    -- Wire up actions for the mapping strings above.
    -- WHY: Mapping strings like "move_selection_next" need to resolve to
    -- actual action functions. Telescope does this automatically when you
    -- pass strings, but we need to handle the <M-p> toggle_preview case.
    local action_layout = require("telescope.actions.layout")

    -- Replace string references with actual functions for special cases
    opts.defaults.mappings.i["<M-p>"] = action_layout.toggle_preview
    opts.defaults.mappings.n["<M-p>"] = action_layout.toggle_preview

    telescope.setup(opts)

    -- Load native FZF sorter (compiled C, must load AFTER setup)
    telescope.load_extension("fzf")
  end,
}
