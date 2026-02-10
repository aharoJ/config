-- path: nvim/lua/plugins/ui/statusline.lua
-- CHANGELOG: 2026-02-10 | Full rebuild following telescope IoC pattern | ROLLBACK: Restore previous statusline.lua from git

---------------------------------------------------------------------------
-- ── PALETTE ─────────────────────────────────────────────────────────────
-- Single source of truth for every color in the statusline.
-- Warm, muted Kanagawa-adjacent tones — NO saturated canonical colors.
---------------------------------------------------------------------------

local p = {
  -- Surfaces (dark to light)
  bg_dark    = "#161616",     -- deepest background (section_b bg)
  bg_mid     = "#1c1e2b",     -- statusline fill (section_c bg)
  bg_accent  = "#292a43",     -- elevated surface (filename chip, mode fg)
  bg_chip    = "#454770",     -- diagnostic/lsp chip background

  -- Foreground
  fg         = "#e3ded7",     -- primary text
  fg_dim     = "#8a8a8a",     -- dimmed/inactive text
  fg_accent  = "#7c7fca",     -- accent text (branch, location)

  -- Mode colors (bg for mode chip)
  normal     = "#7c7fca",     -- muted indigo
  insert     = "#6b806b",     -- muted sage
  visual     = "#d5c28f",     -- warm gold
  command    = "#b48284",     -- dusty rose
  replace    = "#c4746e",     -- muted red

  -- Git diff
  diff_add   = "#a6e3a1",
  diff_mod   = "#f9e2af",
  diff_del   = "#f38ba8",

  -- Inactive (subtle, not alarming)
  inactive   = "#3a3b5e",
}

---------------------------------------------------------------------------
-- ── THEME ───────────────────────────────────────────────────────────────
-- Lualine theme built from palette. Each mode only overrides section_a;
-- sections b/c inherit from normal automatically.
---------------------------------------------------------------------------

local theme = {
  normal = {
    a = { fg = p.bg_accent, bg = p.normal,  gui = "bold" },
    b = { fg = p.fg,        bg = p.bg_dark  },
    c = { fg = p.fg,        bg = p.bg_mid   },
  },
  insert  = { a = { fg = p.bg_accent, bg = p.insert,  gui = "bold" } },
  visual  = { a = { fg = p.bg_accent, bg = p.visual,  gui = "bold" } },
  command = { a = { fg = p.bg_accent, bg = p.command, gui = "bold" } },
  replace = { a = { fg = p.fg,        bg = p.replace, gui = "bold" } },
  inactive = {
    a = { fg = p.fg_dim, bg = p.inactive },
    b = { fg = p.fg_dim, bg = p.inactive },
    c = { fg = p.fg_dim, bg = p.inactive },
  },
}

---------------------------------------------------------------------------
-- ── HELPERS ─────────────────────────────────────────────────────────────
-- Pure functions. No side effects. Each returns a display string or "".
---------------------------------------------------------------------------

local mode_icons = {
  ["NORMAL"]    = "",
  ["INSERT"]    = "",
  ["VISUAL"]    = "",
  ["V-LINE"]    = "",
  ["V-BLOCK"]   = "▧",
  ["SELECT"]    = "",
  ["REPLACE"]   = "",
  ["V-REPLACE"] = "",
  ["COMMAND"]   = "",
  ["TERMINAL"]  = "",
  ["OP"]        = "",
}

local function format_mode(text)
  local icon = mode_icons[text] or ""
  return icon .. " " .. text
end

local function macro_recording()
  local reg = vim.fn.reg_recording()
  return reg ~= "" and (" @" .. reg) or ""
end

local function lsp_clients()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if not clients or #clients == 0 then return "" end
  local names, seen = {}, {}
  for _, c in ipairs(clients) do
    if c.name ~= "copilot" and not seen[c.name] then
      names[#names + 1] = c.name
      seen[c.name] = true
    end
  end
  if #names == 0 then return "" end
  return " " .. table.concat(names, " | ")
end

--- Only show encoding when it's NOT utf-8 (no noise for the common case)
local function encoding_non_default()
  local enc = (vim.bo.fenc ~= "" and vim.bo.fenc) or vim.o.enc
  return enc ~= "utf-8" and enc or ""
end

--- Only show fileformat when it's NOT unix (catch Windows line endings)
local function fileformat_non_default()
  return vim.bo.fileformat ~= "unix" and vim.bo.fileformat or ""
end

---------------------------------------------------------------------------
-- ── COMPONENT CONFIGS ───────────────────────────────────────────────────
-- Each component defined as a standalone table (telescope IoC pattern).
-- Separation: WHAT it shows vs HOW it looks vs WHERE it sits.
---------------------------------------------------------------------------

local comp_mode = {
  "mode",
  fmt = format_mode,
}

local comp_macro = {
  macro_recording,
  padding = { left = 1, right = 0 },
}

local comp_diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  colored = true,
  symbols = { error = " ", warn = " ", info = " ", hint = " " },
  update_in_insert = false,
  color = { bg = p.bg_chip },
  padding = { left = 1, right = 1 },
  separator = { left = "", right = "" },
}

local comp_filename = {
  "filename",
  path = 1,                                    -- relative path
  color = { bg = p.bg_accent, fg = p.fg },
  separator = { left = "", right = "" },
}

local comp_lsp = {
  lsp_clients,
  color = { bg = p.bg_chip, fg = p.fg },
  separator = { left = "", right = "" },
}

local comp_encoding = { encoding_non_default }
local comp_fileformat = { fileformat_non_default }

local comp_location = { "location" }

-- ── Tabline components (git info lives here) ────────────────────────────

local comp_diff = {
  "diff",
  colored = true,
  symbols = { added = " ", modified = " ", removed = " " },
  diff_color = {
    added    = { bg = p.bg_chip, fg = p.diff_add },
    modified = { bg = p.bg_chip, fg = p.diff_mod },
    removed  = { bg = p.bg_chip, fg = p.diff_del },
  },
  separator = { left = "", right = "" },
}

local comp_branch = {
  "branch",
  icon = "",
  color = { bg = p.bg_accent, fg = p.fg_accent },
  separator = { left = "", right = "" },
}

---------------------------------------------------------------------------
-- ── DISABLED FILETYPES ──────────────────────────────────────────────────
-- Statusline hides in these buffers (dashboards, file trees, etc.)
---------------------------------------------------------------------------

local disabled_ft = { "alpha", "starter", "dashboard", "neo-tree", "Outline", "minifiles" }

---------------------------------------------------------------------------
-- ── EXTENSIONS ──────────────────────────────────────────────────────────
-- Only list plugins that are actually in the stack.
-- Constitution: "One of each" — no phantom references.
---------------------------------------------------------------------------

local extensions = {
  "quickfix",
  "man",
  "lazy",
  "mason",
}

---------------------------------------------------------------------------
-- ── PLUGIN SPEC ─────────────────────────────────────────────────────────
---------------------------------------------------------------------------

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },

  init = function()
    -- Global statusline: one bar across all splits (0.11+ recommended)
    vim.opt.laststatus = 3
  end,

  config = function()
    require("lualine").setup({
      options = {
        theme = theme,
        globalstatus = true,
        icons_enabled = true,
        always_divide_middle = true,
        always_show_tabline = false,
        disabled_filetypes = {
          statusline = disabled_ft,
          winbar = {},
        },
      },

      -- ── Active sections ──────────────────────────────────────────
      -- LEFT:  [mode + macro] [diagnostics] [filename ...]
      -- RIGHT: [... lsp clients] [encoding?] [fileformat?] [location]
      sections = {
        lualine_a = { comp_mode, comp_macro },
        lualine_b = { comp_diagnostics },
        lualine_c = { comp_filename },
        lualine_x = {},
        lualine_y = { comp_lsp, comp_encoding, comp_fileformat },
        lualine_z = { comp_location },
      },

      -- ── Inactive: empty (globalstatus handles it) ────────────────
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },

      -- ── Tabline: git info pinned top-right ───────────────────────
      tabline = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { comp_diff, comp_branch },
      },

      winbar = {},
      inactive_winbar = {},
      extensions = extensions,
    })
  end,
}
