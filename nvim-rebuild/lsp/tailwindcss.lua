-- path: nvim/lsp/tailwindcss.lua
-- Description: Native 0.11+ config for tailwindcss-language-server.
--              Auto-discovered by vim.lsp.config() — no require() needed.
--              Provides class name completion, hover preview (generated CSS),
--              diagnostics (invalid classes), and color decorators.
--              This is a THIRD LSP client alongside ts_ls + eslint — no overlap.
--              ts_ls = types. eslint = lint rules. tailwindcss = utility class intelligence.
-- CHANGELOG: 2026-02-11 | IDEI Phase F. Tailwind CSS language expansion.
--            | ROLLBACK: Delete file, remove "tailwindcss" from ensure_installed in lsp.lua

return {
  -- ── Root Detection ────────────────────────────────────────────────────
  -- WHY explicit root_markers: tailwindcss-language-server needs to find
  -- the Tailwind config to know which classes exist (custom theme, plugins).
  -- v4 uses CSS-based config (@config), v3 uses JS/TS config files.
  -- postcss.config listed for projects using Tailwind via PostCSS.
  root_markers = {
    "tailwind.config.js",
    "tailwind.config.ts",
    "tailwind.config.mjs",
    "tailwind.config.cjs",
    "postcss.config.js",
    "postcss.config.ts",
    "postcss.config.mjs",
    "postcss.config.cjs",
  },

  settings = {
    tailwindCSS = {
      -- ── Class Attributes ──────────────────────────────────────────
      -- WHY: Tells tailwindcss-language-server which attributes/props contain
      -- Tailwind classes. Default covers className/class, but we add common
      -- patterns from clsx, cva, and tw-merge used in React projects.
      classAttributes = {
        "class",
        "className",
        "ngClass",
        "class:list",
      },

      -- ── Validation ────────────────────────────────────────────────
      -- WHY: Warn on invalid Tailwind classes. Catches typos like "flex-coll"
      -- instead of "flex-col" before they hit the browser.
      validate = true,

      -- ── Experimental ──────────────────────────────────────────────
      -- WHY classRegex: Enables Tailwind intellisense inside clsx(), cn(),
      -- cva(), and tw`` tagged template literals. Without this, you only
      -- get completions in className="..." but NOT in utility functions.
      experimental = {
        classRegex = {
          -- clsx("...", "...")
          { "clsx\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          -- cn("...", "...")  (shadcn/ui pattern)
          { "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          -- cva("...", { variants: { ... } })
          { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          -- tw`...`  (tagged template literal)
          { "tw`([^`]*)" },
        },
      },
    },
  },
}
