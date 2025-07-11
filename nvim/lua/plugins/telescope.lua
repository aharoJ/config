return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make", cond = vim.fn.executable("make") == 1 },
        { "nvim-telescope/telescope-ui-select.nvim" }
    },
        config = function()
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")
            local themes = require("telescope.themes")
    
            -- Define a base dropdown theme with common settings
            local dropdown_base = themes.get_dropdown({
                winblend = 0,          -- Slight transparency for a modern look
                border = true,          -- Add borders for clarity
                previewer = true,      -- Disable previewer for a compact dropdown
                shorten_path = false,   -- Show full paths for clarity
            })
    
            -- Custom themes for each picker, extending the base theme
            local dropdown_themes = {
                prompt_title          = "Buffers (j/k/⏎)",
                files = vim.tbl_extend("force", dropdown_base, { prompt_title = "Find Files" }),
                grep = vim.tbl_extend("force", dropdown_base, { prompt_title = "Live Grep" }),
                buffers = vim.tbl_extend("force", dropdown_base, {
                previewer             = false,             -- no preview window
                path_display          = { "tail" }, -- **filename only**
                initial_mode          = "normal",  -- start in normal mode
                sort_mru              = true,              -- most-recently-used first
                ignore_current_buffer = true,              -- hide the buf you’re in
                    }),
                symbols = vim.tbl_extend("force", dropdown_base, { prompt_title = "Symbols" }),
                diagnostics = vim.tbl_extend("force", dropdown_base, { prompt_title = "Diagnostics" }),
            }
    
        -- Keymaps for Telescope using our custom dropdown_themes
        -- File navigation (fuzzy search with prompt)
        vim.keymap.set("n", "<leader>ff", function()
            builtin.find_files(dropdown_themes.files)
        end, { desc = "[T] Fuzzy find files" })

        vim.keymap.set("n", "<leader>fn", function()
            -- Find files near current file (including hidden), still fuzzy searching
            local opts = vim.tbl_extend("force", dropdown_themes.files, {
                cwd = vim.fn.expand("%:p:h"), -- current file directory
                hidden = true
            })
            builtin.find_files(opts)
        end, { desc = "[T] nearby files" })

        -- Live Grep (fuzzy find in content with prompt)
        vim.keymap.set("n", "<leader>fg", function()
            builtin.live_grep(dropdown_themes.grep)
        end, { desc = "[T] Live grep in project" })

        -- -- Buffers (view-only list of open buffers)
        -- vim.keymap.set("n", "<leader>gb", function()
        --     builtin.buffers(dropdown_themes.buffers)
        -- end, { desc = "[T] get buffer" })


        -- Diagnostics (current buffer) - DISABLE TYPING HERE!
        vim.keymap.set("n", "<leader>gd", function()
            local opts = vim.tbl_extend("force", dropdown_themes.diagnostics, {
                bufnr = 0,
                initial_mode = "normal", -- Start in normal mode (not insert mode)
                no_prompt = true,        -- Hide the prompt line completely
                prompt_height= 0,
                prompt_line=0,
                results_title = "diagnostic result (j/k/esc)",
            })
            builtin.diagnostics(opts)
        end, { desc = "[T] get diag" })

        vim.keymap.set("n", "<leader>gD", function()
            local opts = vim.tbl_extend("force", dropdown_themes.diagnostics, {
                initial_mode = "normal",
                no_prompt = true,
                prompt_height = 0,
                prompt_line = 0,
                results_title = "project diagnostics (j/k/esc)",
            })
            builtin.diagnostics(opts)
        end, { desc = "[T] get diag for project" })


        -- -- Severity-specific diagnostics (filter errors/warnings/info/hints in buffer)
        -- local function diagnostics_by_severity(sev, title)
        --     return function()
        --         local opts = vim.tbl_extend("force", dropdown_themes.diagnostics, {
        --             bufnr = 0,
        --             severity = sev,
        --             results_title = " " .. title .. " " -- e.g. " ERRORS ", with padding
        --         })
        --         builtin.diagnostics(opts)
        --     end
        -- end
        -- vim.keymap.set("n", "<leader>de", diagnostics_by_severity(vim.diagnostic.severity.ERROR, "ERRORS"),
        --     { desc = "[Diagnostics] Show errors" })
        -- vim.keymap.set("n", "<leader>dw", diagnostics_by_severity(vim.diagnostic.severity.WARN, "WARNINGS"),
        --     { desc = "[Diagnostics] Show warnings" })
        -- vim.keymap.set("n", "<leader>di", diagnostics_by_severity(vim.diagnostic.severity.INFO, "INFO"),
        --     { desc = "[Diagnostics] Show info" })
        -- vim.keymap.set("n", "<leader>dh", diagnostics_by_severity(vim.diagnostic.severity.HINT, "HINTS"),
        --     { desc = "[Diagnostics] Show hints" })

        ------------------------------------------------------------------
        -- Existing Telescope keymaps (ff / fn / fg / gb / fd / gd ...)
        ------------------------------------------------------------------
        vim.keymap.set("n", "<leader>ff", function()
            builtin.find_files(dropdown_themes.files)
        end, { desc = "[T] Fuzzy find files" })

        -- Load Telescope extensions
        telescope.load_extension("ui-select")
        telescope.load_extension("fzf")
    end,
}
