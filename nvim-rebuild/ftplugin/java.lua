-- path: nvim/ftplugin/java.lua
-- Description: Java filetype configuration — launches eclipse.jdt.ls via nvim-jdtls.
--              This file is auto-executed by Neovim on every FileType java event.
--              start_or_attach handles reuse: if a jdtls client with the same root
--              is already running, it attaches to the existing instance.
--
--              ARCHITECTURE DECISION: This file lives in ftplugin/ (not plugins/lang/)
--              because nvim-jdtls's start_or_attach must run on FileType, and ftplugin
--              is the standard Neovim mechanism for that. The lazy.nvim spec for the
--              plugin itself lives in plugins/lang/java.lua.
--
--              CRITICAL: jdtls must NOT be in vim.lsp.enable() — that would start a
--              second, basic jdtls instance that conflicts with this one. jdtls is
--              excluded via mason-lspconfig's automatic_enable.exclude in lsp.lua.
--
-- CHANGELOG: 2026-02-11 | IDEI Phase F2 build. Java language expansion via nvim-jdtls
--            (ftplugin pattern). Formatting disabled (conform + google-java-format).
--            Debugging/testing deferred to future phase.
--            | ROLLBACK: Delete this file, remove nvim-jdtls from plugins/lang/java.lua,
--            remove "jdtls" from ensure_installed in lsp.lua

-- ── Guard: only run if nvim-jdtls is installed ──────────────────────────
-- WHY: ftplugin/java.lua runs on EVERY FileType java event, even before
-- lazy.nvim has loaded plugins. If nvim-jdtls isn't installed yet (first
-- launch, lazy hasn't synced), fail silently instead of erroring.
local ok, jdtls = pcall(require, "jdtls")
if not ok then
  return
end

-- ── Mason paths ─────────────────────────────────────────────────────────
-- WHY: Mason installs jdtls to a standard location. We resolve paths once
-- here instead of scattering vim.fn.glob() calls throughout the config.
local mason_registry = vim.fn.stdpath("data") .. "/mason"
local jdtls_install = mason_registry .. "/packages/jdtls"
local jdtls_bin = mason_registry .. "/bin/jdtls"

-- ── Verify jdtls is installed ───────────────────────────────────────────
if not vim.uv.fs_stat(jdtls_bin) then
  vim.notify(
    "[IDEI] jdtls not found. Run :MasonInstall jdtls",
    vim.log.levels.WARN
  )
  return
end

-- ── Lombok ──────────────────────────────────────────────────────────────
-- WHY: Lombok generates getters/setters/builders at compile time. Without the
-- javaagent flag, jdtls can't see generated methods — every @Data class shows
-- errors. Mason bundles lombok.jar with the jdtls package.
local lombok_jar = jdtls_install .. "/lombok.jar"

-- ── Project identification ──────────────────────────────────────────────
-- WHY explicit root_markers: jdtls needs to know the project root to resolve
-- classpath, dependencies, and workspace settings. gradlew/mvnw before .git
-- because build tools define the actual project boundary in monorepos.
local root_dir = vim.fs.root(0, {
  "gradlew",
  "mvnw",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
  ".git",
})

-- WHY fallback to cwd: Single-file Java editing (rare but possible).
-- jdtls needs SOME root to create a workspace directory.
if not root_dir then
  root_dir = vim.fn.getcwd()
end

-- WHY project_name: Each project gets its own jdtls workspace directory.
-- Without this, jdtls uses a shared workspace and projects cross-pollinate
-- cached state — phantom errors, stale classpath, corrupted indexes.
local project_name = vim.fs.basename(root_dir)

-- ── Per-project workspace directories ───────────────────────────────────
-- WHY separate config + workspace: jdtls stores project-specific state
-- (compiled indexes, classpath cache, settings) in the -data directory.
-- Sharing this across projects causes corruption. Each project gets its own.
local cache_dir = vim.fn.stdpath("cache") .. "/jdtls/" .. project_name
local config_dir = cache_dir .. "/config"
local workspace_dir = cache_dir .. "/workspace"

-- ── Build the command ───────────────────────────────────────────────────
-- WHY jdtls wrapper script: Mason's jdtls bin is a Python wrapper that
-- handles platform detection (config_mac/config_linux/config_win), launcher
-- jar glob, and JVM startup. Saves us from hardcoding version-specific paths.
-- The wrapper requires Python 3.9+.
local cmd = {
  jdtls_bin,
  "-configuration", config_dir,
  "-data", workspace_dir,
}

-- WHY jvm-arg for lombok: The wrapper script accepts --jvm-arg flags that
-- get passed through to the JVM. javaagent must be set at JVM startup.
if vim.uv.fs_stat(lombok_jar) then
  table.insert(cmd, string.format("--jvm-arg=-javaagent:%s", lombok_jar))
end

-- ── Bundles (debugging + testing — future phase) ────────────────────────
-- WHY empty: java-debug-adapter and vscode-java-test bundles go here when
-- we add debugging support. The architecture supports it without restructuring.
-- Just populate this table and add DAP keymaps.
local bundles = {}

-- ── Future: java-debug-adapter ──────────────────────────────────────────
-- local java_debug_jar = vim.fn.glob(
--   mason_registry .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
--   true
-- )
-- if java_debug_jar ~= "" then
--   table.insert(bundles, java_debug_jar)
-- end

-- ── Future: vscode-java-test ────────────────────────────────────────────
-- local java_test_jars = vim.fn.glob(
--   mason_registry .. "/packages/java-test/extension/server/*.jar",
--   true, true  -- returns a list
-- )
-- vim.list_extend(bundles, java_test_jars)

-- ── The config table ────────────────────────────────────────────────────
-- WHY start_or_attach: This is nvim-jdtls's core function. It checks if a
-- jdtls client with the same name + root_dir is already running. If yes,
-- attaches to it (no duplicate server). If no, starts a new one.
-- This file runs on EVERY FileType java event — the guard is essential.
local config = {
  name = "jdtls",
  cmd = cmd,
  root_dir = root_dir,

  -- ── Server settings ─────────────────────────────────────────────────
  -- Reference: https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
  settings = {
    java = {
      -- ── Signature Help ──────────────────────────────────────────
      signatureHelp = {
        enabled = true,               -- Show parameter info as you type
        description = { enabled = true },
      },

      -- ── Completion ──────────────────────────────────────────────
      -- WHY favoriteStaticMembers: Common static imports that jdtls should
      -- suggest without requiring a full class path. These are the standard
      -- Java/Spring/testing static imports that every Java dev uses.
      completion = {
        favoriteStaticMembers = {
          "org.junit.Assert.*",
          "org.junit.jupiter.api.Assertions.*",
          "org.mockito.Mockito.*",
          "org.hamcrest.MatcherAssert.*",
          "org.hamcrest.Matchers.*",
          "java.util.Objects.requireNonNull",
          "java.util.Objects.requireNonNullElse",
        },
        filteredTypes = {
          "com.sun.*",                -- Hide internal JDK types from completion
          "io.micrometer.shaded.*",   -- Hide shaded (relocated) packages
          "java.awt.*",              -- Hide AWT (not used in Spring Boot)
          "jdk.*",                   -- Hide JDK internal types
          "sun.*",                   -- Hide sun internal types
        },
        importOrder = {               -- Import organization order
          "java",
          "javax",
          "org",
          "com",
          "",                         -- Blank line separator
          "#",                        -- Static imports last
        },
      },

      -- ── Sources ─────────────────────────────────────────────────
      sources = {
        organizeImports = {
          starThreshold = 9999,       -- Never use wildcard imports (explicit > *)
          staticStarThreshold = 9999, -- Never use static wildcard imports
        },
      },

      -- ── Code Generation ─────────────────────────────────────────
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
        },
        hashCodeEquals = {
          useJava7Objects = true,      -- Use Objects.hash() / Objects.equals()
        },
        useBlocks = true,              -- Use blocks in generated code
      },

      -- ── Formatting ──────────────────────────────────────────────
      -- WHY disabled: Formatting is google-java-format's job via conform.nvim.
      -- jdtls formatting uses Eclipse's internal formatter which produces
      -- different output. One tool per job.
      format = {
        enabled = false,
      },

      -- ── Inlay Hints ────────────────────────────────────────────
      inlayHints = {
        parameterNames = {
          enabled = "all",            -- Show parameter names in method calls
        },
      },

      -- ── References Code Lens ───────────────────────────────────
      referencesCodeLens = {
        enabled = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
    },
  },

  -- ── Initialization Options ──────────────────────────────────────────
  init_options = {
    bundles = bundles,
    -- WHY extendedClientCapabilities: nvim-jdtls provides extended capabilities
    -- that standard LSP doesn't cover. These enable jdtls-specific features
    -- like organize imports, extract variable, generate code.
    extendedClientCapabilities = jdtls.extendedClientCapabilities,
  },

  -- ── Formatting Kill (belt-and-suspenders) ───────────────────────────
  -- WHY: Same pattern as ts_ls and eslint. Even though format.enabled = false
  -- above, we also kill the LSP capability at the client level. Triple kill:
  -- 1. java.format.enabled = false (server-side)
  -- 2. on_attach capability kill (client-side)
  -- 3. conform lsp_format = "never" (formatting engine refuses LSP)
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false

    -- ── Java-specific keymaps ─────────────────────────────────────
    -- WHY: nvim-jdtls provides additional commands beyond standard LSP.
    -- These are jdtls-specific and only make sense in Java buffers.
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "<leader>Jo", function() jdtls.organize_imports() end,
      vim.tbl_extend("force", opts, { desc = "Java: Organize imports" }))
    vim.keymap.set("n", "<leader>Jv", function() jdtls.extract_variable() end,
      vim.tbl_extend("force", opts, { desc = "Java: Extract variable" }))
    vim.keymap.set("v", "<leader>Jv", function() jdtls.extract_variable(true) end,
      vim.tbl_extend("force", opts, { desc = "Java: Extract variable (visual)" }))
    vim.keymap.set("n", "<leader>Jc", function() jdtls.extract_constant() end,
      vim.tbl_extend("force", opts, { desc = "Java: Extract constant" }))
    vim.keymap.set("v", "<leader>Jc", function() jdtls.extract_constant(true) end,
      vim.tbl_extend("force", opts, { desc = "Java: Extract constant (visual)" }))
    vim.keymap.set("v", "<leader>Jm", function() jdtls.extract_method(true) end, vim.tbl_extend("force", opts, { desc = "Java: Extract method (visual)" }))

    -- ── Debugging keymaps (future phase) ────────────────────────
    -- vim.keymap.set("n", "<leader>Jt", function() jdtls.test_class() end,
    --   vim.tbl_extend("force", opts, { desc = "Java: Test class" }))
    -- vim.keymap.set("n", "<leader>Jn", function() jdtls.test_nearest_method() end,
    --   vim.tbl_extend("force", opts, { desc = "Java: Test nearest method" }))
  end,
}

-- ── Capabilities (blink.cmp) ────────────────────────────────────────────
-- WHY: jdtls.start_or_attach() bypasses vim.lsp.config(), so blink.cmp's
-- automatic capability wiring (via plugin/blink-cmp.lua) doesn't reach jdtls.
-- Without this, jdtls only sees resolveSupport = { "additionalTextEdits", "command" }
-- — missing "documentation" and "detail". Result: completion popup shows only
-- the short type name (e.g. "java.lang.Integer") instead of full Javadoc.
config.capabilities = require("blink.cmp").get_lsp_capabilities()

-- ── Launch ──────────────────────────────────────────────────────────────
jdtls.start_or_attach(config)
