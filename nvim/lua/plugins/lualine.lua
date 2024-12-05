-- LSP clients attached to buffer
local clients_lsp = function()
  local bufnr = vim.api.nvim_get_current_buf()

  ---@diagnostic disable-next-line: deprecated
  local clients = vim.lsp.buf_get_clients(bufnr) -- updated version breaks it
  if next(clients) == nil then
    return ""
  end

  local c = {}
  for _, client in pairs(clients) do
    table.insert(c, client.name)
  end
  return "  " .. table.concat(c, "|")
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "RRethy/base16-nvim", -- enhanches themes?
  },
  config = function()
    require("onedark").setup() -- IMPRTANT
    -- require("tokyonight").setup()
    local default_icon = "  "
    local mode_map = {
      -- ['NORMAL'] = '󰘳  ',
      -- ['O-PENDING'] = '  ',
      -- ['INSERT'] = '  ',
      -- ['VISUAL'] = '󰒉  ',
      -- ['V-BLOCK'] = '󰒉  ',
      -- ['V-LINE'] = '󰒉  ',
      -- ['V-REPLACE'] = '  ',
      -- ['REPLACE'] = '󰛔  ',
      -- ['COMMAND'] = '󰘳  ',
      -- ['SHELL'] = '  ',
      -- ['TERMINAL'] = '  ',
      -- ['EX'] = '  ',
      -- ['S-BLOCK'] = '  ',
      -- ['S-LINE'] = '  ',
      -- ['SELECT'] = '  ',
      -- ['CONFIRM'] = '  ',
      -- ['MORE'] = '  ',
    }

    local mode = {
      "mode",
      fmt = function(s)
        local icon = mode_map[s] or default_icon
        -- local icon = mode_map[s] or default_icon
        return icon .. s
      end,
    }

    local diagnostics = {
      "diagnostics",
      symbols = { error = " ", warn = " ", info = " ", hint = "󰌵 " },
      colored = true,        -- Displays diagnostics status in color if set to true.
      update_in_insert = false, -- Update diagnostics in insert mode.
      always_visible = false, -- Show diagnostics even if there are none.
    }

    local filetype = {
      "filetype",
      colored = true,         -- Displays filetype icon in color if set to true
      icon_only = false,      -- Display only an icon for filetype
      icon = { align = "left" }, -- Display filetype icon on the right hand side
      -- icon =    {'X', align='right'}
      -- Icon string ^ in table is ignored in filetype component
    }

    local diff = {
      "diff",
      colored = true, -- Displays a colored diff status if set to true
      symbols = {
        added = " ",
        modified = " ",
        removed = " ",
      },         -- Changes the symbols used by the diff.
      source = nil, -- A function that works as a data source for diff.
    }

    local filename = {
      "filename",
      file_status = true,  -- Displays file status (readonly status, modified status)
      newfile_status = false, -- Display new file status (new file means no write after created)
      path = 4,            -- 0 | 1 | 2 | 3 | 4

      shorting_target = 40, -- Shortens path to leave 40 spaces in the window
      -- for other components. (terrible name, any suggestions?)
      symbols = {
        modified = "[] ", -- Text to show when the file is modified.
        readonly = " ", -- Text to show when the file is non-modifiable or readonly.
        unnamed = " [No Name]", -- Text to show for unnamed buffers.
        newfile = " [New File]", -- Text to show for newly created file before first write
      },
    }

    local help = { sections = { lualine_a = { { "filetype", colored = false } } }, filetypes = { "help" } }
    local alpha = {
      sections = {
        lualine_a = {
          mode,
        },
        lualine_b = {
          "branch",
        },
        lualine_z = { "hostname" },
      },
      filetypes = { "alpha" },
    }
    local dashboard = {
      sections = {
        lualine_a = {
          mode,
        },
        lualine_b = {
          "branch",
        },
        lualine_z = { filetype },
      },
      filetypes = { "dashboard" },
    }

    local telescope = {
      sections = {
        lualine_a = {
          mode,
        },
        lualine_x = { filetype },
      },
      filetypes = { "TelescopePrompt" },
    }

    local branch = {
      "branch",
      icon = "", -- you can set an icon of your choice
      color = { fg = "#808080", gui = "bold" }, -- sets the foreground to gray, adjust as needed
    }

    --  CUSTOM MODE COLORS
    local custom_onedark = require("lualine.themes.onedark")
    custom_onedark.normal.a.fg = "#8A8DE0"
    custom_onedark.visual.a.fg = "#b8b57d"
    custom_onedark.insert.a.fg = "#77BE84"

    require("lualine").setup({
      options = {
        icons_enabled = true,
        -- theme = "onedark", -- signature design
        theme = custom_onedark,
        component_separators = { left = "  ", right = "  " },
        section_separators = { left = "", right = "" },
        -- section_separators = { left = '', right = ''},

        disabled_filetypes = {},
        always_divide_middle = true,
        globalstatus = true,
        refresh = {     -- sets how often lualine should refresh it's contents (in ms)
          statusline = 1000, -- The refresh option sets minimum time that lualine tries
          tabline = 1000, -- to maintain between refresh. It's not guarantied if situation
          winbar = 1000, -- arises that lualine needs to refresh itself before this time
        },
      },
      sections = {
        lualine_a = { mode },
        lualine_b = { diagnostics },
        lualine_c = {
          filename,
        },
        lualine_x = {
          {
            require("noice").api.status.mode.get,
            cond = require("noice").api.status.mode.has,
            color = { link = "lualine_b_diff_added_insert" },
          },
          -- 'searchcount',
          "selectioncount",
          filetype,
        },
        lualine_y = { clients_lsp },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { filename },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {
        lualine_a = {
          {
            "buffers",
            show_filename_only = true,                          -- IMPORTANT cuz false is whack
            hide_filename_extension = true,                     -- Hide .java | .py | etc...
            show_modified_status = true,                        -- Shows indicator when the buffer is modified.
            use_mode_colors = true,                             -- change colors with MODE
            color = { fg = "#808080", bg = "#303030", gui = "bold" }, -- sets the foreground to gray, adjust as needed
            mode = 0,                                           -- 0 | 1 | 2 | 3 | 4
            max_length = vim.o.columns * 2 / 3,                 -- Maximum width of buffers component,
            filetype_names = {
              TelescopePrompt = "Telescope",
              dashboard = "Dashboard",
              packer = "Packer",
              fzf = "FZF",
              alpha = "Alpha",
            },
            symbols = {
              modified = " ●", -- Text to show when the buffer is modified
              alternate_file = "#", -- Text to show to identify the alternate file
              directory = "", -- Text to show when the buffer is a directory
            },
          },
        },
        lualine_z = {
          diff, -- git
          branch, -- git
        },
      },
      extensions = {
        "toggleterm",
        "trouble",
        "lazy",
        "nvim-tree",
        help,
        alpha,
        "quickfix",
        dashboard,
        telescope,
      },
    })
  end,
}
