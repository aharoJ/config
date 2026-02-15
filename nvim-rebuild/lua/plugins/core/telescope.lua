-- path: nvim-rebuild/lua/plugins/core/telescope.lua

local find_files_opts = {
  -- STRATEGY
    layout_strategy = "center",

    -- CONFIG
    layout_config = {
        width = 0.4,
        height = 0.35,
    },

    -- COSMETICS
    previewer = false,
    border = false,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

local buffers_opts = {
    -- STRATEGY
    layout_strategy = "vertical",

    -- CONFIG
    layout_config = {
        width = 0.6,
        height = 0.9,
        preview_height = 0.45,
        preview_cutoff = 1,  -- forces preview to ALWAYS show
        prompt_position = "top",
        mirror = true,
    },

    -- COSMETICS
    previewer = true,
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    prompt_title = "Get Buffers",
    results_title = false,
    path_display = { "filename_first" },
    sorting_strategy = "ascending",
}

local current_buffer_fuzzy_find_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.8,
        height = 0.8,
        preview_height = 0.5,
        preview_cutoff = 1,  -- forces preview to ALWAYS show
        prompt_position = "top",
        mirror = true,
    },
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    sorting_strategy = "ascending",
}

local grep_string_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.6,
        height = 0.6,
        preview_height = 0.4,
        preview_cutoff = 1,  -- forces preview to ALWAYS show
        prompt_position = "top",
        mirror = true,
    },
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { "filename_first" },
    sorting_strategy = "ascending",
}

local live_grep_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.8,
        height = 0.9,
        preview_height = 0.4,
        preview_cutoff = 1,  -- forces preview to ALWAYS show
        prompt_position = "top",
        mirror = true,
    },
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { "filename_first" },
    sorting_strategy = "ascending",
}

local diagnostics_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.8,
        height = 0.9,
        preview_height = 0.4,
        preview_cutoff = 1,  -- forces preview to ALWAYS show
        prompt_position = "top",
        mirror = true,
    },
    border = true,
    borderchars = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗" },
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { "filename_first" },
    sorting_strategy = "ascending",
}

-- preview_cutoff = 1,  -- forces preview to ALWAYS show
-- Screen
--  └─ height (total picker size)
--      ├─ prompt (fixed ~1 line)
--      ├─ results (whatever's left)
--      └─ preview_height (share of the picker height)

return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
      -- GET
        { "<leader>gf", function() require("telescope.builtin").find_files(find_files_opts) end, desc = "[get] file", },
        { "<leader>gb", function() require("telescope.builtin").buffers(buffers_opts) end, desc = "[get] buffer", },
        { "<leader>g,", function() require("telescope.builtin").current_buffer_fuzzy_find(current_buffer_fuzzy_find_opts) end, desc = "[get] ," },
        { "<leader>gw", function() require("telescope.builtin").grep_string(grep_string_opts) end, desc = "[get] word" },
        { "<leader>g.", function() require("telescope.builtin").live_grep(live_grep_opts) end, desc = "[get] grep" },

        -- LSP
        { "<leader>df", function() require("telescope.builtin").diagnostics(vim.tbl_extend("force", diagnostics_opts, { bufnr = 0 })) end, desc = "[diagnostics] find (buffer)" },
        { "<leader>dF", function() require("telescope.builtin").diagnostics(diagnostics_opts) end, desc = "[diagnostics] find (workspace)" },
        { "<leader>gr", function() require("telescope.builtin").lsp_references(live_grep_opts) end, desc = "[get] references" },
        { "<leader>gd", function() require("telescope.builtin").lsp_definitions(live_grep_opts) end, desc = "[get] definitions" },
        { "<leader>gi", function() require("telescope.builtin").lsp_implementations(live_grep_opts) end, desc = "[get] implementations" },
        { "<leader>gt", function() require("telescope.builtin").lsp_type_definitions(live_grep_opts) end, desc = "[get] type definitions" },
        { "<leader>gs", function() require("telescope.builtin").lsp_document_symbols(live_grep_opts) end, desc = "[get] document symbols" },
        { "<leader>gS", function() require("telescope.builtin").lsp_dynamic_workspace_symbols(live_grep_opts) end, desc = "[get] workspace symbols" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                prompt_prefix = "  ",
                selection_caret = "  ",
                entry_prefix = "   ",
                sorting_strategy = "ascending",
                file_ignore_patterns = { "node_modules", ".git/" },
            },
        })
    end,
}
