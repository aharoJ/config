return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  config = function()
    local wk = require("which-key")
    wk.setup({
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },
      operators = { gc = "Comments" },
      key_labels = {},
      motions = {
        count = true,
      },
      icons = {
        breadcrumb = "»",
        separator = "➜",
        group = "+",
      },
      popup_mappings = {
        scroll_down = "<c-d>",
        scroll_up = "<c-u>",
      },
      window = {
        border = "none",     -- none | single | double |shadow
        position = "bottom", -- bottom | top
        margin = { 1, 0, 1, 0 },
        padding = { 1, 2, 1, 2 },
        winblend = 0, -- 0 for Transparent
        zindex = 1000,
      },
      layout = {
        height = { min = 4, max = 30 },
        width = { min = 4, max = 25 },
        spacing = 3,          -- spacing between columns
        align = "center",     -- align columns left, center or right
      },
      ignore_missing = false, -- IMPORTANT leave as FALSE
      hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "^:", "^ ", "^call ", "^lua " },
      show_help = true,
      show_keys = true,
      triggers = "auto",
      triggers_nowait = {
        -- marks
        "",
        "'",
        "g",
        "g'",
        -- registers
        '"',
        "<c-r>",
        -- spelling
        "z=",
      },
      triggers_blacklist = {
        i = { "j", "k" },
        v = { "j", "k" },
      },
      disable = {
        buftypes = {},
        filetypes = {},
      },
    })

    -------------------    START    ------------------------
    wk.register({
      ["<leader>"] = {

        -------------------    Signle Character    ------------------------
        e = "NeoTree", -- NeoTree
        ["/"] = "Comment",
        q = "Quit",

        -------------------    DEBUG    ------------------------
        d = {
          name = "+Debug",
          t = "Toggle Breakpoint",
          c = "Continue",
          x = "Terminate",
          o = "Step Over",
          i = "Step Into",
          O = "Step OUT",
        },

        -------------------    BUFFER    ------------------------
        b = {
          name = "+Buffer", -- all under settings.lua
          c = "Close Buffer",
          n = "Next Buffer",
          p = "Previous Buffer",
          sv = "Split Vertical",
          sh = "Split Horizontal",
          wc = "Close Window",
        },

        -------------------    TELESCOPE    ------------------------
        f = {
          name = "+Find",
          -- f = "Find Files",
          g = "Live Grep",
          b = "Buffers",
          h = "Help Tags",
        },

        -------------------    TOGGLE    ------------------------
        t = {
          name = "+Toggle",
          l = "LSP Diagnostics", -- lsp-config.lua
          c = "CoPilot",         -- git.lua
          g = "Gitsigns",        -- git.lua
        },

        -------------------    CODE    ------------------------
        c = {
          name = "+Code",
          d = "Go to Definition",
          D = "Go to Declaration",
          r = "List References",
          a = "Show Code Actions",
          i = "Go to Implementation",
          S = "Show Signature Help",
          wa = "Add Workspace Folder",
          wr = "Remove Workspace Folder",
          R = "Rename Symbol",
          ["[d"] = "Go to Previous Diagnostic",
          ["]d"] = "Go to Next Diagnostic",
          o = "Open Diagnostic Float",
          q = "Set Loclist with Diagnostics",
          t = "Go to Type Definition",
          f = "Format Code",
          p = "Prettier Format ",
          P = "Prettier Check",
        },

        -- -------------------    RUN    ------------------------
        -- r = {
        -- 	name = "+Run",
        -- 	p = "Project",
        -- 	f = "File",
        -- },

        -------------------    GET    ------------------------
        g = {
          name = "+Get",
          f = "File",
          b = "Buffer",
          B = "NeoTree Buffer",
        },
      },
      {
        mode = "n", -- NORMAL mode
        prefix = "",
        buffer = nil,
        silent = true,
        noremap = true,
        nowait = false,
        expr = false,
      },
    })
  end,
}
