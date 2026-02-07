-- return  {
--     "windwp/nvim-autopairs",
--     event = "InsertEnter",
--     opts = {
--       check_ts = true,
--       fast_wrap = { map = "<M-e>", offset = -1 },
--       disable_filetype = { "TelescopePrompt", "spectre_panel" },
--     },
--     config = function(_, opts)
--       require("nvim-autopairs").setup(opts)
--       -- NOTE: do NOT require("nvim-autopairs.completion.cmp") here,
--       -- since you're using Blink (not cmp). Base autopairs works fine.
--     end,
--   }

-- path: nvim/lua/plugins/autocomplete/autopairs.lua
return      {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = { check_ts = true, fast_wrap = { map = "<M-e>", offset = -1 }, disable_filetype = { "TelescopePrompt", "spectre_panel" } },
        config = function(_, opts)
            require("nvim-autopairs").setup(opts)
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            local cmp = require("cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    }