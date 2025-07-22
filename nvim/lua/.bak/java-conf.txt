-- path: ~/.config/nvim/lua/java-conf.lua
local M = {}

function M.setup()
    -- Debug mappings
    vim.keymap.set("n", "<leader>da", require("jdtls.dap").test_class, { desc = "Debug test class" })
    vim.keymap.set("n", "<leader>b", require("dap").toggle_breakpoint, { desc = "Toggle breakpoint" })

    -- Test mappings
    vim.keymap.set("n", "<leader>tm", require("jdtls").test_nearest_method, { desc = "Test method" })
    vim.keymap.set("n", "<leader>tc", require("jdtls").test_class, { desc = "Test class" })
end

return M
