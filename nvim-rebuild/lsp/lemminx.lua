-- path: nvim/lsp/lemminx.lua
-- Description: Native 0.11+ config for lemminx (Eclipse XML Language Server).
--              Auto-discovered by vim.lsp.config(). Handles ALL XML concerns:
--              diagnostics, completion, formatting, hover, code actions.
--
--              EXCEPTION TO "NO LSP FORMATTING" RULE:
--              lemminx is the ONLY formatter for XML. There is no external CLI
--              alternative (no "xmlfmt" or "xml-formatter" in conform). The
--              <leader>cf format keymap detects this and falls back to
--              vim.lsp.buf.format() for filetypes without a conform formatter.
--
--              CRITICAL: lemminx uses init_options (NOT settings) for configuration.
--              nvim-lspconfig#3739 confirms: settings = { xml = { ... } } results
--              in vim.empty_dict() at initialization. Must use init_options.
--
--              Schema-aware for: Maven POM, Spring XML configs, XSD, XSL/XSLT, SVG.
--              Requires Java runtime (Mason installs the binary, but Java must be on PATH).
--
-- CHANGELOG: 2026-02-12 | IDEI Phase F7 build. XML language expansion.
--            | ROLLBACK: Delete file, remove "lemminx" from ensure_installed in lsp.lua
return {
  -- ── Root Detection ──────────────────────────────────────────────────
  -- WHY: Maven multi-module projects have hierarchical pom.xml files.
  -- .git catches everything; pom.xml provides tighter scoping for Maven projects.
  root_markers = { "pom.xml", ".git" },

  -- ── Initialization Options ──────────────────────────────────────────
  -- WHY init_options instead of settings: lemminx reads configuration from
  -- initializationOptions.settings, NOT from the standard LSP settings field.
  -- This is documented in the lemminx repo and confirmed by nvim-lspconfig#3739.
  init_options = {
    settings = {
      xml = {
        -- ── Server Configuration ────────────────────────────────────
        server = {
          -- WHY: lemminx creates a cache directory at ~/.lemminx by default.
          -- This pollutes $HOME. XDG spec says cache goes in ~/.cache/.
          workDir = "~/.cache/lemminx",
        },
        -- ── Formatting ──────────────────────────────────────────────
        -- WHY: lemminx IS the formatter for XML. These settings control
        -- how it formats when vim.lsp.buf.format() is called via <leader>cf.
        format = {
          enabled = true,
          -- WHY splitAttributes: POM files and Spring configs are more readable
          -- with attributes on separate lines when there are many.
          -- "alignWithFirstAttr" aligns subsequent attributes with the first.
          splitAttributes = "alignWithFirstAttr",
          -- WHY joinContentLines: Keeps text content on fewer lines for readability.
          joinContentLines = true,
          -- WHY preservedNewlines: Allow 1 blank line between sections for visual grouping.
          preservedNewlines = 1,
          -- WHY insertFinalNewline: Consistent with every other filetype in the PDE.
          insertFinalNewline = true,
        },
        -- ── Validation ──────────────────────────────────────────────
        validation = {
          -- WHY: Schema-based validation is lemminx's killer feature for POM files
          -- and Spring configs. Catches typos in XML element names and attributes.
          enabled = true,
        },
        -- ── Completion ──────────────────────────────────────────────
        completion = {
          -- WHY: Auto-close tags saves keystrokes on deeply nested XML.
          autoCloseTag = true,
          autoCloseSelfClosing = true,
        },
      },
    },
  },
  -- ── NOTE: No on_attach formatting kill ──────────────────────────────
  -- WHY: Unlike every other LSP server in this PDE, lemminx KEEPS its
  -- documentFormattingProvider capability because it IS the formatter.
  -- The format keymap in formatting.lua handles this via LSP fallback.
}
