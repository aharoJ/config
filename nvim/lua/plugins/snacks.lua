return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- Core snacks
    animate = {enabled = true,},
    bigfile = { enabled = true },
    bufdelete = { enabled = true },
    dim = { enabled = true },
    gitbrowse = { enabled = true }, 
    health= {enabled = true }, 
    rename = { enabled = true },
    scroll = { enabled = true },
    terminal = { enabled = true },
    util = { enabled = true },
    words = { enabled = true }, -- dope af
    indent = { enabled = false }, -- ON!
    dashboard = { enabled = false }, -- OFF
    debug = { enabled = false }, -- OFF
    explorer = { enabled = false }, -- OFF
    git = { enabled = false }, -- OFF
    input = { enabled = false }, -- OFF
    layout = { enabled = false }, -- OFF
    lazygit = { enabled = false }, -- OFF
    notifier = { enabled = false }, -- OFF
    notify = { enabled = false }, -- OFF
    picker = { enabled = false }, -- OFF
    profiler = { enabled = false }, -- OFF (lua only)
    quickfile = { enabled = false }, -- OFF
    scope = { enabled = false }, -- OFF
    scratch = { enabled = false }, -- OFF
    statuscolumn = { enabled = false }, -- OFF
    toggle = { enabled = false }, -- OFF
    win = { enabled = false }, -- OFF
    zen = { enabled = false }, -- OFF
  },
  keys = {
    { "<leader>n",  function() Snacks.notifier.show_history() end,   desc = "Notification History" },
    { "<leader>cR", function() Snacks.rename.rename_file() end,      desc = "Rename File" },
    { "<leader>go", function() Snacks.gitbrowse() end,               desc = "Git Browse",                  mode = { "n", "v" } },
    -- { "<leader>gx", function() Snacks.git.blame_line() end,          desc = "Git Blame Line" },
    { "<leader>lf", function() Snacks.lazygit.log_file() end,        desc = "Lazygit Current File History" },
    { "<leader>gl", function() Snacks.lazygit() end,                 desc = "Lazygit" },
    { "<leader>ll", function() Snacks.lazygit.log() end,             desc = "Lazygit Log (cwd)" },
    { "<leader>tt", function() Snacks.terminal() end,                desc = "Toggle Terminal" },
    { "<c-_>",      function() Snacks.terminal() end,                desc = "which_key_ignore" },
    { "]]",         function() Snacks.words.jump(vim.v.count1) end,  desc = "Next Reference",              mode = { "n", "t" } },
    { "[[",         function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference",              mode = { "n", "t" } },
    {
      "<leader>N",
      desc = "Neovim News",
      function()
        Snacks.win({
          file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
          },
        })
      end,
    }
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map(
          "<leader>uc")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.indent():map("<leader>ti")
        Snacks.toggle.dim():map("<leader>td") -- toggle dim 
      end,
    })
  end,
}
