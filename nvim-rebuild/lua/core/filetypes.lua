-- path: nvim/lua/core/filetypes.lua
-- Description: Custom filetype detection and overrides.
--              Neovim's built-in filetype.lua handles most cases.
--              Only add entries here for files Neovim gets wrong or doesn't recognize.
-- CHANGELOG: 2026-02-03 | Created (placeholder for custom detections) | ROLLBACK: Delete file

vim.filetype.add({
  extension = {
    mdx = "markdown",               -- MDX files (Next.js/React) treated as markdown
    env = "sh",                      -- .env files get shell syntax (close enough for highlighting)
  },
  filename = {
    [".env"] = "sh",
    [".env.local"] = "sh",
    [".env.development"] = "sh",
    [".env.production"] = "sh",
  },
  pattern = {
    ["%.config/ghostty/config"] = "toml",  -- Ghostty config (when it's rebuilt)
  },
})
