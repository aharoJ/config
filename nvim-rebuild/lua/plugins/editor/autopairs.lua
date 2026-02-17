-- path: nvim-rebuild/lua/plugins/editor/autopairs.lua
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  AUTO-CLOSE: Brackets + Tags                                           ║
-- ║  One tool per job:                                                     ║
-- ║    mini.pairs  → brackets, quotes:  () {} [] "" '' ``                  ║
-- ║    ts-autotag  → HTML/JSX tags:     <div> → </div>                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

return {

  -- ── Bracket / Quote Auto-Pairing ──────────────────────────────────────
  -- WHY mini.pairs over autopairs.nvim: zero-config, no conflicts with
  -- blink.cmp, handles skip-over and backspace deletion natively.
  {
    "echasnovski/mini.pairs",
    version = false,
    event = "InsertEnter",
    opts = {
      -- Each mapping: [1]=open, [2]=close, [3]=pair
      -- Default covers () {} [] "" '' `` — no overrides needed.
      mappings = {
        ["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]." },
        ["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]." },
        ["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]." },
        [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
        ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
        ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
        ['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^\\].", register = { cr = false } },
        ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%a\\].", register = { cr = false } },
        ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].", register = { cr = false } },
      },
    },
  },

  -- ── HTML / JSX Tag Auto-Close & Rename ────────────────────────────────
  -- WHY: Treesitter-powered — understands JSX fragments, self-closing
  -- tags, and renames both open+close tags simultaneously.
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      opts = {
        enable_close = true, -- Auto-close <div> → <div></div>
        enable_rename = true, -- Rename <div> → <span> updates </div> → </span>
        enable_close_on_slash = true, -- Typing </ auto-completes closing tag
      },
      -- Only activate for filetypes that actually use tags
      per_filetype = {
        ["html"] = { enable_close = true },
        ["xml"] = { enable_close = true },
        ["typescriptreact"] = { enable_close = true },
        ["javascriptreact"] = { enable_close = true },
        ["markdown"] = { enable_close = false }, -- Avoid conflicts with md syntax
      },
    },
  },
}
