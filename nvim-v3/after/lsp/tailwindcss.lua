-- path: ~/.config/nvim-v3/after/lsp/tailwindcss.lua
-- description: Tailwind CSS class intelligence
-- patched: Phase 3 (D24, D26)
return {
  root_markers = {
    "tailwind.config.js", "tailwind.config.ts", "tailwind.config.mjs", "tailwind.config.cjs",
    "postcss.config.js", "postcss.config.ts", "postcss.config.mjs", "postcss.config.cjs",
  },
  settings = {
    tailwindCSS = {
      classAttributes = { "class", "className", "ngClass", "class:list" },
      validate = true,
      experimental = {
        classRegex = {
          { "clsx\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          { "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*)[\"'`]" },
          { "tw`([^`]*)`" },
        },
      },
    },
  },
}
