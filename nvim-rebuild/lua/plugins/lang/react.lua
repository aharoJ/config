-- path: nvim/lua/plugins/lang/react.lua
-- Description: Context-aware commentstring using treesitter.
--              Fixes JSX/TSX comments ({/* */} inside markup, // in logic).
--              Works WITH built-in gcc/gc (0.10+), not a replacement.
-- CHANGELOG: 2026-02-16 | Added for JSX/TSX context-aware commenting.
--            | ROLLBACK: Delete file

return {
  "folke/ts-comments.nvim",
  event = "VeryLazy",
  opts = {},
}
