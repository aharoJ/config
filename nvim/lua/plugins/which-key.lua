return 
{
    "folke/which-key.nvim",
    dependencies = { 'echasnovski/mini.nvim', version = false },
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      -- Plugin settings
      plugins = {
        marks = true,           -- Enable mark plugin
        registers = true,       -- Enable registers plugin
        spelling = {
          enabled = true,       -- Enable spelling suggestions
          suggestions = 20,     -- Number of suggestions
        },
        presets = {
          operators = true,     -- Help for operators (d, y, etc.)
          motions = true,       -- Help for motions
          text_objects = true,  -- Help for text objects
          windows = true,       -- Help for <c-w> bindings
          nav = true,           -- Misc navigation bindings
          z = true,             -- Help for z-prefixed bindings (folds, etc.)
          g = true,             -- Help for g-prefixed bindings
        },
      },
  
      -- Icons for the popup
      icons = {
        breadcrumb = "»",       -- Symbol for active key combo
        separator = "➜",        -- Symbol between key and label
        group = "+",            -- Symbol for groups
      },
  
      -- Key bindings within the popup
      keys = {
        scroll_down = "<c-d>",  -- Scroll down in popup
        scroll_up = "<c-u>",    -- Scroll up in popup
      },
  
      -- Window settings
      win = {
        border = "none",        -- Border style
        padding = { 1, 2, 1, 2 }, -- Padding [top, right, bottom, left]
        wo = {
          winblend = 0,         -- Transparency (0 = opaque)
        },
        zindex = 1000,          -- Window stacking order
      },
  
      -- Layout settings
      layout = {
        height = { min = 4, max = 30 }, -- Min/max height of popup
        width = { min = 4, max = 25 },  -- Min/max width of columns
        spacing = 3,                    -- Spacing between columns
        align = "center",               -- Column alignment
      },
  
      -- General settings
      show_help = true,         -- Show help message in command line
      show_keys = true,         -- Show pressed key in command line
      triggers = {              -- Explicitly set triggers as a table
        { "<auto>", mode = "nixsotc" },
      },
      disable = {
        buftypes = {},          -- Disable for specific buffer types
        filetypes = {},         -- Disable for specific filetypes
      },
  
      -- Your keybinding descriptions
      spec = {
        -- Single character mappings
        { "<leader>e", desc = "NeoTree", mode = "n" },
        { "<leader>/", desc = "Comment", mode = "n" },
        { "<leader>q", desc = "Quit", mode = "n" },
  
        -- Debug group
        { "<leader>d", group = "Debug", mode = "n" },
        { "<leader>dt", desc = "Toggle Breakpoint", mode = "n" },
        { "<leader>dc", desc = "Continue", mode = "n" },
        { "<leader>dx", desc = "Terminate", mode = "n" },
        { "<leader>do", desc = "Step Over", mode = "n" },
        { "<leader>di", desc = "Step Into", mode = "n" },
        { "<leader>dO", desc = "Step Out", mode = "n" },
  
        -- Buffer group
        { "<leader>b", group = "Buffer", mode = "n" },
        { "<leader>bc", desc = "Close Buffer", mode = "n" },
        { "<leader>bn", desc = "Next Buffer", mode = "n" },
        { "<leader>bp", desc = "Previous Buffer", mode = "n" },
        { "<leader>bsv", desc = "Split Vertical", mode = "n" },
        { "<leader>bsh", desc = "Split Horizontal", mode = "n" },
        { "<leader>bwc", desc = "Close Window", mode = "n" },
  
        -- Find (Telescope) group
        { "<leader>f", group = "Find", mode = "n" },
        { "<leader>fg", desc = "Live Grep", mode = "n" },
        { "<leader>fb", desc = "Buffers", mode = "n" },
        { "<leader>fh", desc = "Help Tags", mode = "n" },
  
        -- Toggle group
        { "<leader>t", group = "Toggle", mode = "n" },
        { "<leader>tl", desc = "LSP Diagnostics", mode = "n" },
        { "<leader>tc", desc = "CoPilot", mode = "n" },
        { "<leader>tg", desc = "Gitsigns", mode = "n" },
  
        -- Code group
        { "<leader>c", group = "Code", mode = "n" },
        { "<leader>cd", desc = "Go to Definition", mode = "n" },
        { "<leader>cD", desc = "Go to Declaration", mode = "n" },
        { "<leader>cr", desc = "List References", mode = "n" },
        { "<leader>ca", desc = "Show Code Actions", mode = "n" },
        { "<leader>ci", desc = "Go to Implementation", mode = "n" },
        { "<leader>cS", desc = "Show Signature Help", mode = "n" },
        { "<leader>cwa", desc = "Add Workspace Folder", mode = "n" },
        { "<leader>cwr", desc = "Remove Workspace Folder", mode = "n" },
        { "<leader>cR", desc = "Rename Symbol", mode = "n" },
        { "<leader>c[d", desc = "Go to Previous Diagnostic", mode = "n" },
        { "<leader>c]d", desc = "Go to Next Diagnostic", mode = "n" },
        -- { "<leader>co", desc = "Open Diagnostic Float religious = "n",        -- Avoid religious mappings
        { "<leader>cq", desc = "Set Loclist with Diagnostics", mode = "n" },
        { "<leader>ct", desc = "Go to Type Definition", mode = "n" },
        { "<leader>cf", desc = "Format Code", mode = "n" },
        { "<leader>cp", desc = "Prettier Format", mode = "n" },
        { "<leader>cP", desc = "Prettier Check", mode = "n" },
  
        -- Get group
        { "<leader>g", group = "Get", mode = "n" },
        { "<leader>gf", desc = "File", mode = "n" },
        { "<leader>gB", desc = "Buffer", mode = "n" },
        { "<leader>gb", desc = "NeoTree Buffer", mode = "n" },
      },
    },
  }
