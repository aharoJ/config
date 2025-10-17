-- path: lua/plugins/telescope.lua

return {
  "nvim-telescope/telescope.nvim",
  version = "0.1.x",
  event = "VeryLazy",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function() return vim.fn.executable("make") == 1 end,
    },
    { "nvim-telescope/telescope-ui-select.nvim", lazy = true },
    -- { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font ~= false },
  },

  -- Minimal, high-signal keymaps
  keys = {
    -- Files / grep
    { "<leader>ff", function() require("telescope.builtin").find_files({ hidden = true }) end, desc = "[󰭎] Files" },
    { "<leader>fg", function() require("telescope.builtin").live_grep() end,desc = "[󰭎] Grep" },
    { "<leader>fb", function() require("telescope.builtin").buffers() end,desc = "[󰭎] Buffers" },
    { "<leader>fo", function() require("telescope.builtin").oldfiles({ only_cwd = true }) end,desc = "[󰭎] Recent (cwd)" },
    { "<leader>fr", function() require("telescope.builtin").resume() end,desc = "[󰭎] Resume" },
    -- ..
    -- ..
    -- ..
    { "<leader>fw", function() require("telescope.builtin").grep_string({ use_regex = false,additional_args = { "--fixed-strings" }, }) end, desc = "[󰭎] Grep word/selection" },
    { "<leader>fO", function() require("telescope.builtin").live_grep({ grep_open_files = true,}) end, desc = "[󰭎] Grep (open files)" },
    { "<leader>fN", function() require("telescope.builtin").find_files({ hidden = true, follow = true, search_file = vim.fn.input("file name > "), }) end, desc = "[󰭎] Files by name" },
    { "<leader>f,", function() require("telescope.builtin").current_buffer_fuzzy_find({ results_ts_highlight = true, }) end, desc = "[󰭎] Buffer fuzzy" },
    { "<leader>f.", function() require("telescope.builtin").live_grep() end, desc = "[󰭎] Project fuzzy text" },


    -- Git
    { "<leader>ggc", function() require("telescope.builtin").git_commits() end,desc = "[󰭎][git] commits" },
    { "<leader>ggs", function() require("telescope.builtin").git_status() end,desc = "[󰭎][git] status" },
    -- ..
    -- ..
    -- ..
    { "<leader>ggf", function() require("telescope.builtin").git_files({ show_untracked = true, recurse_submodules = false }) end, desc = "[󰭎][git] files" },
    { "<leader>ggb", function() require("telescope.builtin").git_branches({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][git] branches" },
    { "<leader>ggB", function() require("telescope.builtin").git_bcommits({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][git] buffer commits" },
    { "<leader>ggR", function() require("telescope.builtin").git_bcommits_range({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][git] range history" },
    { "<leader>ggS", function() require("telescope.builtin").git_stash({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][git] stash" },


    -- LSP essentials
    { "gd",function() require("telescope.builtin").lsp_definitions() end,desc = "[󰭎][lsp] defs" },
    { "gD",function() vim.lsp.buf.declaration() end, desc = "[󰭎][lsp] declaration" },
    -- { "gr",function() require("telescope.builtin").lsp_references({ include_declaration = false }) end, desc = "[󰭎][lsp] refs" },
    { "gT",function() require("telescope.builtin").lsp_type_definitions() end,desc = "[󰭎][lsp] type defs" },
    { "gi",function() require("telescope.builtin").lsp_implementations({ show_line = false, fname_width = 80, layout_strategy = "vertical", layout_config   = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][lsp] implementations" },
    { "<leader>ci", function() require("telescope.builtin").lsp_incoming_calls() end,desc = "[󰭎][lsp] incoming calls" },
    { "<leader>cO", function() require("telescope.builtin").lsp_outgoing_calls() end,desc = "[󰭎][lsp] outgoing calls" },
    { "<leader>cs", function() require("telescope.builtin").lsp_document_symbols({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][lsp] document symbols" },
    { "<leader>cC", function() require("telescope.builtin").lsp_document_symbols({ symbols = { "class", "interface", "struct", "module" }, layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][lsp] classes/interfaces" },
    { "<leader>cS", function() local q = vim.fn.input("workspace symbols > ") if q and #q > 0 then require("telescope.builtin").lsp_workspace_symbols({ query = q }) end end, desc = "[󰭎][lsp] workspace symbols (prompt)" },
    { "<leader>cD", function() require("telescope.builtin").lsp_dynamic_workspace_symbols({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, }) end, desc = "[󰭎][lsp] workspace symbols (dynamic)" },
    { "<leader>ca", function() vim.lsp.buf.code_action() end,desc = "[󰭎][lsp] code action" },
    { "<leader>cr", function() vim.lsp.buf.rename() end,desc = "[󰭎][lsp] rename" },



    -- Diagnostics (focused filters)
    { "<leader>da", function() require("telescope.builtin").diagnostics({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, line_width = math.max(60, math.floor(vim.o.columns * 0.55)), }) end, desc = "[󰭎][diag] (all)" },
    { "<leader>db", function() require("telescope.builtin").diagnostics({ bufnr = 0, layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, line_width = math.max(60, math.floor(vim.o.columns * 0.55)), }) end, desc = "[󰭎][diag] (buffer)" },
    { "<leader>de", function() require("telescope.builtin").diagnostics({ severity = "ERROR" }) end, desc = "[󰭎][diag] (errors)" },
    { "<leader>dw", function() require("telescope.builtin").diagnostics({ severity = "WARN"  }) end, desc = "[󰭎][diag] (warnings)" },
    { "<leader>di", function() require("telescope.builtin").diagnostics({ severity = "INFO"  }) end, desc = "[󰭎][diag] (info)" },
    { "<leader>dh", function() require("telescope.builtin").diagnostics({ severity = "HINT"  }) end, desc = "[󰭎][diag] (hints)" },
    { "<leader>dW", function() require("telescope.builtin").diagnostics({ severity_limit = "WARN" }) end, desc = "[󰭎][diag] (≥ warn)" },
    { "<leader>dP", function() require("telescope.builtin").diagnostics({ root_dir = vim.loop.cwd() }) end, desc = "[󰭎][diag] (project/cwd)" },
    { "<leader>dv", function() local cfg = vim.diagnostic.config() vim.diagnostic.config({ virtual_text = not cfg.virtual_text }) vim.notify("diagnostic virtual_text: " .. (not cfg.virtual_text and "ON" or "OFF")) end, desc = "[󰭎][diag] toggle virtual text" },
    -- ..
    -- ..
    -- ..
    { "<leader>dS", function() require("telescope.builtin").diagnostics({ sort_by = "severity",layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, line_width = "full",             }) end, desc = "[󰭎][diag] workspace (severity-first)" },
    { "<leader>dB", function() require("telescope.builtin").diagnostics({ bufnr = 0, no_unlisted = true,layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, line_width = math.max(60, math.floor(vim.o.columns * 0.55)), }) end, desc = "[󰭎][diag] buffer (listed only)" },
    { "<leader>dR", function() require("telescope.builtin").diagnostics({ root_dir = true,layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, line_width = "full", }) end, desc = "[󰭎][diag] workspace (cwd only)" },



    -- Vim pickers 
    { "<leader>g;", function() require("telescope.builtin").command_history() end, desc = "[󰭎] command history" },
    { "<leader>g/", function() require("telescope.builtin").search_history() end, desc = "[󰭎] search history" },
    -- ..
    -- ..
    -- ..
    { "<leader>gk", function() require("telescope.builtin").keymaps() end, desc = "[󰭎] keymaps" },
    { "<leader>gH", function() require("telescope.builtin").help_tags({ layout_strategy = "vertical", layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" }, fallback = true, }) end, desc = "[󰭎] help tags" },
    { "<leader>tc", function() require("telescope.builtin").colorscheme({ enable_preview = true }) end, desc = "[󰭎] colorschemes" },
    -- ..
    -- ..
    -- ..
    { "<leader>gl", function() if #vim.fn.getloclist(0) == 0 then vim.diagnostic.setloclist({ open = false }) end require("telescope.builtin").loclist() end, desc = "[󰭎] loclist" },
    { "<leader>gL", function() require("telescope.builtin").diagnostics({ bufnr = 0 }) end, desc = "[󰭎] loclist ." },

  },

  opts = function()
    local has_fd = vim.fn.executable("fd") == 1
    local has_rg = vim.fn.executable("rg") == 1

    local vimgrep_args = has_rg and {
      "rg", "--color=never", "--no-heading", "--with-filename",
      "--line-number", "--column", "--smart-case", "--hidden",
      "--glob", "!.git/*",
    } or nil

    local find_command = has_fd and
      { "fd", "--type", "f", "--strip-cwd-prefix", "--hidden", "--exclude", ".git" } or
      (has_rg and { "rg", "--files", "--hidden", "--glob", "!.git/*" } or nil)

    return {
      defaults = {
        sorting_strategy = "ascending",
        layout_strategy = "horizontal",
        layout_config = {
          width = 0.95, height = 0.90,
          horizontal = { prompt_position = "top", preview_width = 0.55 },
        },
        prompt_prefix = "   ",
        selection_caret = " ",
        path_display = { "truncate", filename_first = { reverse_directories = true } },
        vimgrep_arguments = vimgrep_args,
        file_ignore_patterns = { "^%.git/", "node_modules", "target", "dist", "build", "^%.next/", "%.lock" },
        mappings = {
          i = {
            ["<Esc>"] = require("telescope.actions").close,
            ["<C-j>"] = require("telescope.actions").move_selection_next,
            ["<C-k>"] = require("telescope.actions").move_selection_previous,
            ["<C-u>"] = require("telescope.actions").preview_scrolling_up,
            ["<C-d>"] = require("telescope.actions").preview_scrolling_down,
            ["<C-q>"] = require("telescope.actions").smart_send_to_qflist
                        + require("telescope.actions").open_qflist,
          },
          n = {
            ["q"] = require("telescope.actions").close,
            ["<C-q>"] = require("telescope.actions").smart_send_to_qflist
                        + require("telescope.actions").open_qflist,
          },
        },
      },

      pickers = {
        -- speed wins
        find_files = { hidden = true, follow = true, previewer = false, find_command = find_command },
        buffers    = { sort_mru = true, ignore_current_buffer = true, previewer = false, path_display = function(_, path)
      local parts = vim.split(path, "/")
      local n = #parts
      if n > 2 then
        return table.concat({ parts[n - 1], parts[n] }, "/")
      else
        return path
      end
    end, },

        -- LSP QoL
        lsp_references        = { include_declaration = false, show_line = false, fname_width = 80 },
        lsp_definitions       = { show_line = false, fname_width = 80 },
        lsp_type_definitions  = { show_line = false, fname_width = 80 },
        lsp_implementations   = { show_line = false, fname_width = 80 },

        -- Diagnostics (focused, legible)
        diagnostics = {
          layout_strategy = "vertical",
          layout_config = { width = 0.9, height = 0.95, preview_height = 0.55, prompt_position = "top" },
          line_width = math.max(60, math.floor(vim.o.columns * 0.55)),
          no_sign = false,
        },

        -- Vim pickers polish
        help_tags   = { fallback = true },
        colorscheme = { enable_preview = false },
        command_history = {},
        search_history  = {},
        quickfix        = {},
        quickfixhistory = {},
        loclist         = {},
        tags            = {},
        current_buffer_tags = {},
      },

      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
        ["ui-select"] = function()
          return require("telescope.themes").get_dropdown {
            previewer = false,
            sorting_strategy = "ascending",
            layout_config = { width = 0.5, height = 0.4, prompt_position = "top" },
          }
        end,
      },
    }
  end,

  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
    pcall(telescope.load_extension, "ui-select")
  end,
}
