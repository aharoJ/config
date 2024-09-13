return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.6",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-ui-select.nvim",
  },
  config = function()
    local actions = require("telescope.actions")
    require("telescope").setup({
      defaults = {
        vimgrep_arguments = {
          'rg',
          '--color=never',
          '--no-heading',
          '--with-filename',
          '--line-number',
          '--column',
          '--smart-case',
          '--hidden',
        },
      },
      mappings = {
        i = {
          ["<esc>"] = actions.close,
        },
      },
      pickers = {
        find_files = {
          theme = "ivy",           -- dropdown, cursor, ivy,
          layout_config = {
            width = 0.9,
            height = 0.9,
          },
          hidden = true,           -- This will make the 'find_files' picker include hidden files by default.
        },
        -- Uncomment and configure live_grep if needed
        -- live_grep = {
        -- 	theme = "dropdown",
        -- 	layout_config = {
        -- 		width = 0.6, -- Customize the width for live_grep
        -- 		height = 0.6, -- Customize the height for live_grep
        -- 	},
        -- },
      },
      extensions = {
        ["ui-select"] = {
          require("telescope.themes").get_dropdown({}),
        },
      },
    })

    local builtin = require("telescope.builtin")
    vim.keymap.set("n", "<leader>gf", builtin.find_files, {})     -- Updated to '<leader>ff' for find_files
    vim.keymap.set("n", "<leader>gB", builtin.buffers, {})
    vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
    vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})

    -- Load extensions after configuring Telescope
    require("telescope").load_extension("ui-select")
  end,
}
