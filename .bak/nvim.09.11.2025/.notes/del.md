hmm do you agree?


---

CHATGPT SAID THIS ONE WON 

angel, i got you. i took the best ideas from your samples (A & E win) and fused them into a clean, 2025-style layout: **jdtls is started per-project via a tiny module**, never touched by mason-lspconfig, with **fast workspaces, DAP & tests auto-wired, Lombok optional, multi-JDK runtimes, and zero bloat**. it’s feature-rich but buttery-smooth.

here’s the exact tree and full files you can drop in.

---

# eza -T (final layout)

```
~/.config/nvim
├─ init.lua
├─ lazy-lock.json
├─ ftplugin
│  └─ java.lua                      # java-local editor prefs (no LSP start here)
└─ lua
   ├─ config
   │  └─ lazy.lua
   ├─ core
   │  └─ jdtls.lua                  # all jdtls brains live here
   └─ plugins
      ├─ autopairs.lua
      ├─ treesitter.lua
      ├─ themes
      │  └─ kanagawa.lua
      └─ lsp
         ├─ setup.lua               # your general LSP; do NOT manage jdtls here
         └─ java.lua                # lazy.nvim spec that boots core.jdtls
```

---

# 1) `lua/plugins/lsp/java.lua` — lazy.nvim plugin spec

```lua
-- path: ~/.config/nvim/lua/plugins/lsp/java.lua
return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "neovim/nvim-lspconfig",
      -- Completion capabilities if you use cmp (safe if installed)
      "hrsh7th/cmp-nvim-lsp",
      -- Debugging / testing (recommended)
      { "mfussenegger/nvim-dap", lazy = true },
      { "rcarriga/nvim-dap-ui",  lazy = true, config = true },
      { "theHamsta/nvim-dap-virtual-text", lazy = true, config = true },
    },
    config = function()
      -- keep jdtls fully separate from mason-lspconfig
      require("core.jdtls").setup_autocmd()
    end,
  },
}
```

---

# 2) `lua/core/jdtls.lua` — the tuned, pro-grade bootstrap

```lua
-- path: ~/.config/nvim/lua/core/jdtls.lua
-- Ultra-tuned JDTLS bootstrap for large Spring/Gradle/Maven repos (2025).
-- • Never managed by mason-lspconfig. Starts on FileType=java.
-- • Auto DAP + Test bundles (if installed).
-- • Optional Lombok, Spring Tools jars.
-- • Multi-JDK runtimes via env vars. Minimal globals. Smooth defaults.

local M = {}

-- ── tiny utils ────────────────────────────────────────────────────────────────
local uv, fn = (vim.uv or vim.loop), vim.fn

local function is_dir(p)  return p and #p > 0 and (uv.fs_stat(p) or {}).type == "directory" end
local function is_file(p) return p and #p > 0 and (uv.fs_stat(p) or {}).type == "file"      end

local function first_glob(pattern)
  local g = fn.glob(pattern)
  if g == "" then return nil end
  return vim.split(g, "\n", { trimempty = true })[1]
end

local function all_glob(pattern)
  local g = fn.glob(pattern)
  if g == "" then return {} end
  return vim.split(g, "\n", { trimempty = true })
end

local function os_config_dir()
  if fn.has("mac") == 1 then return "config_mac" end
  if fn.has("unix") == 1 then return "config_linux" end
  return "config_win" -- win users can override with $JDTLS_HOME if needed
end

local function project_root()
  local markers = {
    "mvnw", "pom.xml",
    "gradlew", "build.gradle", "settings.gradle", "settings.gradle.kts",
    ".git",
  }
  local ok, setup = pcall(require, "jdtls.setup")
  if ok then return setup.find_root(markers) or uv.cwd() end
  return uv.cwd()
end

local function project_name(root) return vim.fs.basename(root) end

-- ── mason / env paths ─────────────────────────────────────────────────────────
local function mason_base() return fn.stdpath("data") .. "/mason" end

local function jdtls_base_dir()
  local env = vim.env.JDTLS_HOME
  if env and is_dir(env) then return env end
  local mason = mason_base() .. "/packages/jdtls"
  if is_dir(mason) then return mason end
  return nil -- user must install JDTLS (via Mason or manually)
end

local function lombok_jar()
  local env = vim.env.LOMBOK_JAR
  if env and is_file(env) then return env end
  local nightly = mason_base() .. "/packages/lombok-nightly/lombok.jar"
  if is_file(nightly) then return nightly end
  local stable  = mason_base() .. "/packages/lombok/lombok.jar"
  if is_file(stable) then return stable end
  local local_drop = fn.stdpath("data") .. "/java/lombok.jar"
  if is_file(local_drop) then return local_drop end
  return nil
end

local function debug_bundle()
  return first_glob(mason_base()
    .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
end

local function test_bundles()
  return all_glob(mason_base() .. "/packages/java-test/extension/server/*.jar")
end

local function spring_bundles()
  -- optional: export SPRING_TOOLS_JAR_DIR=/path/to/*.jar for extra goodies
  local dir = vim.env.SPRING_TOOLS_JAR_DIR
  if not (dir and is_dir(dir)) then return {} end
  return all_glob(dir .. "/*.jar")
end

-- ── runtimes (Java 17/21/23/24…) ─────────────────────────────────────────────
local function jdk_runtime(name, envvar, fallback_path, default_)
  local p = vim.env[envvar] or fallback_path
  if p and is_dir(p) then return { name = name, path = p, default = default_ or false } end
end

local function configured_runtimes()
  -- jdtls requires Java 21+ to run, but you can target 17/21/23/…
  local r, home = {}, vim.env.JAVA_HOME -- fallback for default
  local add = function(rt) if rt then table.insert(r, rt) end end
  add(jdk_runtime("JavaSE-17", "JAVA_17_HOME", nil, false))
  add(jdk_runtime("JavaSE-21", "JAVA_21_HOME", home, true))  -- default
  add(jdk_runtime("JavaSE-23", "JAVA_23_HOME", nil, false))
  add(jdk_runtime("JavaSE-24", "JAVA_24_HOME", nil, false))
  return r
end

-- ── capabilities / on_attach ──────────────────────────────────────────────────
local function lsp_capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp = pcall(require, "cmp_nvim_lsp")
  if ok then caps = cmp.default_capabilities(caps) end
  return caps
end

local function on_attach(_, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end
  local jdtls = require("jdtls")

  -- java power actions (keep minimal; you likely have global LSP maps)
  map("n", "<leader>jo", jdtls.organize_imports, "Java: Organize Imports")
  map("v", "<leader>jv", jdtls.extract_variable, "Java: Extract Variable")
  map("v", "<leader>jm", jdtls.extract_method,   "Java: Extract Method")
  map("n", "<leader>js", jdtls.super_implementation, "Java: Super Implementation")
  map("n", "<leader>jj", jdtls.javap, "Java: Disassemble (javap)")
  map("n", "<leader>jh", jdtls.jshell, "Java: JShell")

  -- DAP wiring (if present)
  if pcall(require, "dap") then
    jdtls.setup_dap({ hotcodereplace = "auto" })
    jdtls.dap.setup_dap_main_class_configs()
  end

  -- keep main class configs fresh after saves
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    group = vim.api.nvim_create_augroup("JdtlsMainClassRefresh", { clear = false }),
    callback = function() pcall(jdtls.dap.setup_dap_main_class_configs) end,
  })
end

-- ── command builder ───────────────────────────────────────────────────────────
local function build_cmd(jdtls_home, workspace_dir)
  local launcher = first_glob(jdtls_home .. "/plugins/org.eclipse.equinox.launcher_*.jar")
  local config   = jdtls_home .. "/" .. os_config_dir()
  local java_bin = vim.env.JDTLS_JAVA or "java"
  local xmx      = vim.env.JDTLS_XMX or "2G"

  local cmd = {
    java_bin,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Dfile.encoding=UTF-8",
    "-Xms512m",
    "-Xmx" .. xmx,
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher,
    "-configuration", config,
    "-data", workspace_dir,
  }

  local lombok = lombok_jar()
  if lombok then table.insert(cmd, 8, "-javaagent:" .. lombok) end -- safe position
  return cmd
end

local function extended_capabilities()
  local ec = require("jdtls").extendedClientCapabilities
  ec.resolveAdditionalTextEditsSupport = true
  ec.progressReportProvider = true
  ec.classFileContentsSupport = true
  return ec
end

local function bundles_all()
  local list, dbg = {}, debug_bundle()
  if dbg then table.insert(list, dbg) end
  local tests = test_bundles()
  if #tests > 0 then vim.list_extend(list, tests) end
  local spring = spring_bundles()
  if #spring > 0 then vim.list_extend(list, spring) end
  return list
end

local function settings_java()
  return {
    java = {
      eclipse = { downloadSources = true },
      maven   = { downloadSources = true, updateSnapshots = true },
      signatureHelp = { enabled = true },
      references = { includeDecompiledSources = true },
      contentProvider = { preferred = "fernflower" },
      completion = {
        favoriteStaticMembers = {
          "org.assertj.core.api.Assertions.*",
          "org.mockito.Mockito.*",
          "org.hamcrest.MatcherAssert.assertThat",
          "org.hamcrest.Matchers.*",
          "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
          "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
          "java.util.Objects.requireNonNull",
          "java.util.Optional.*",
        },
        filteredTypes = { "com.sun.*", "sun.*", "java.awt.*", "javax.swing.*" },
      },
      sources = {
        organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
      },
      format = {
        enabled = false, -- point to your XML if you want jdtls to format
        -- settings = { url = "/abs/path/to/eclipse-formatter.xml", profile = "YourProfile" },
      },
      configuration = {
        updateBuildConfiguration = "interactive", -- "automatic" if you prefer
        runtimes = configured_runtimes(),
      },
      inlayHints = { parameterNames = { enabled = "literals" } },
      implementationsCodeLens = { enabled = true },
      referencesCodeLens      = { enabled = true },
    },
  }
end

-- ── start/attach ──────────────────────────────────────────────────────────────
function M.start_or_attach()
  local root = project_root()
  if not root or root == "" then
    vim.notify("[jdtls] no project root found", vim.log.levels.WARN)
    return
  end

  local jdtls_home = jdtls_base_dir()
  if not jdtls_home then
    vim.notify("[jdtls] eclipse.jdt.ls not found. Install via :Mason or set $JDTLS_HOME", vim.log.levels.ERROR)
    return
  end

  local ws = fn.stdpath("data") .. "/jdtls/workspace/" .. project_name(root)
  fn.mkdir(ws, "p")

  local jdtls = require("jdtls")
  local config = {
    cmd = build_cmd(jdtls_home, ws),
    root_dir = root,
    settings = settings_java(),
    init_options = {
      bundles = bundles_all(),
      extendedClientCapabilities = extended_capabilities(),
    },
    capabilities = lsp_capabilities(),
    on_attach = on_attach,
    flags = { allow_incremental_sync = true, debounce_text_changes = 80 },
  }

  jdtls.start_or_attach(config)
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    group = vim.api.nvim_create_augroup("JdtlsAutoStart", { clear = true }),
    callback = function() M.start_or_attach() end,
  })
end

return M
```

---

# 3) `ftplugin/java.lua` — filetype-local comforts (no server start here)

```lua
-- path: ~/.config/nvim/ftplugin/java.lua
-- keep LSP boot in core.jdtls; this is just editor feel per buffer.
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.expandtab = true
vim.opt_local.foldmethod = "indent"
vim.opt_local.foldlevel = 99

-- organize imports + format on save (toggle if you prefer)
local aug = vim.api.nvim_create_augroup("JavaFmtSave", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  buffer = 0,
  callback = function()
    pcall(function() require("jdtls").organize_imports() end)
    vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
  end,
})
```

---

# 4) `lua/plugins/lsp/setup.lua` — make sure you do **not** manage jdtls here

```lua
-- path: ~/.config/nvim/lua/plugins/lsp/setup.lua
-- example scaffold; configure your other servers as you like.
return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lsp = require("lspconfig")
      local ok, cmp = pcall(require, "cmp_nvim_lsp")
      local caps = vim.lsp.protocol.make_client_capabilities()
      if ok then caps = cmp.default_capabilities(caps) end

      -- examples:
      -- lsp.lua_ls.setup({ capabilities = caps })
      -- lsp.ts_ls.setup({ capabilities = caps })
      -- lsp.pyright.setup({ capabilities = caps })

      -- IMPORTANT: do NOT call lsp.jdtls.setup(...) or vim.lsp.enable("jdtls").
      -- jdtls is fully handled by core.jdtls.
    end,
  },
}
```

---

## recommended installs

inside `:Mason`:

* **jdtls**
* **java-debug-adapter**
* **java-test**
* (optional) **lombok** or **lombok-nightly**

env (nice & explicit for enterprise repos):

```bash
# the JDK the *server* runs on (>=21 strongly recommended)
export JAVA_21_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
# target JDKs for projects:
export JAVA_17_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home

# (optional) memory for jdtls process:
export JDTLS_XMX=4G

# (optional) lombok & spring tools (if you use them)
export LOMBOK_JAR="$HOME/.local/share/nvim/java/lombok.jar"
export SPRING_TOOLS_JAR_DIR="$HOME/.local/share/nvim/java/spring-tools"
```

---

## why this is “the one”

* **proper separation of concerns**: a tiny **module** owns boot, not mason-lspconfig; your ftplugin stays UI-only.
* **predictable workspaces**: `~/.local/share/nvim/jdtls/workspace/<project>` keeps indexing fast across sessions.
* **real-world Spring**: filtered noisy types, imports-on-save, decompiler set to fernflower, test/debug bundles, inlay hints.
* **portable**: auto-detect mason paths, but also respects your `$JDTLS_HOME`, `$LOMBOK_JAR`, `$JAVA_XX_HOME` if you roll your own.
* **no bloat**: everything lazy-loads on `FileType java`; DAP/test bundles are only picked up if installed.

if you want, we can also drop a tiny `:JdtlsInfo` command or wire a dap-ui toggle (`<leader>du`) just for java buffers—say the word and i’ll add it. 💅✨

---

CLAUDE.AI SAID THIS ONE WON 

After analyzing all five samples for a professional Java/Spring Boot development setup, **Sample A** is the clear winner. Here's why it's the best choice for a professional Software Engineer:I've analyzed all five samples and **Sample A** is definitively the best choice for professional Java/Spring development. Here's the complete setup with the tree structure you requested:

```bash
# Current structure after implementing Sample A:
~/.config/nvim/
├── init.lua
├── lazy-lock.json
├── ftplugin/
│   └── java.lua                 # ⭐ Main JDTLS configuration
└── lua/
    ├── config/
    │   └── lazy.lua
    ├── core/
    │   ├── diagnostics.lua
    │   ├── globals.lua
    │   └── options.lua
    ├── plugins/
    │   ├── autopairs.lua
    │   ├── lsp/
    │   │   ├── setup.lua        # Updated to exclude jdtls
    │   │   └── java.lua         # Plugin specification
    │   ├── themes/
    │   │   └── kanagawa.lua
    │   └── treesitter.lua
    └── util/
        └── path.lua             # Cross-platform utilities
```

**Why Sample A wins:**

1. **Architecture**: Uses the industry-standard `ftplugin/java.lua` approach, keeping JDTLS completely separate from mason-lspconfig to prevent conflicts
2. **Performance**: Persistent workspaces per project, incremental sync, and smart bundle filtering for faster startups
3. **Professional features**: Spring Boot optimized completions, multi-JDK support, auto-formatting, and comprehensive DAP integration
4. **Maintainability**: Clean modular design with proper error handling and cross-platform compatibility
5. **Enterprise ready**: Handles large Maven/Gradle projects with optimized memory settings and build tool integration

The other samples have various issues:
- **Sample B**: Hardcoded paths, poor error handling, overly complex
- **Sample C**: Incomplete (cuts off mid-configuration)
- **Sample D**: Also incomplete
- **Sample E**: Good but more complex than needed, less Spring-optimized

Sample A provides the perfect balance of professional features, performance, and maintainability that a senior software engineer would expect. The configuration is production-ready and follows best practices for enterprise Java development environments.

# Professional JDTLS Setup for Neovim (2025)

## Why Sample A is the Best Choice

**Sample A** provides the most professional, production-ready configuration for several reasons:

### Architecture Excellence
- **Clean separation**: Uses `ftplugin/java.lua` for startup logic (industry standard)
- **Modular design**: Separates concerns between plugin management and configuration
- **No global pollution**: Keeps jdtls separate from mason-lspconfig to prevent conflicts

### Performance Optimizations
- **Persistent workspaces**: Project-specific workspace directories for faster subsequent opens
- **Incremental sync**: `allow_incremental_sync = true` with smart debouncing
- **Bundle filtering**: Excludes unnecessary JARs that slow down startup
- **Memory efficient**: Proper JVM flags and resource management

### Professional Features
- **Spring Boot optimized**: Includes Spring-specific static imports and completion favorites
- **Multiple JDK support**: Clean runtime configuration for Java 17/21+ projects
- **Enterprise build support**: Handles large Maven/Gradle projects efficiently
- **Auto-formatting**: Organize imports + format on save (configurable)

### Robustness
- **Error handling**: Graceful degradation when bundles aren't available
- **Cross-platform**: Works on macOS, Linux, and Windows
- **Environment aware**: Respects JAVA_HOME and custom paths
- **Safe defaults**: Conservative settings that work in team environments

## Complete File Structure

```
~/.config/nvim/
├── init.lua
├── lazy-lock.json
├── ftplugin/
│   └── java.lua                 # ⭐ Main JDTLS configuration
└── lua/
    ├── config/
    │   └── lazy.lua
    ├── core/
    │   ├── diagnostics.lua
    │   ├── globals.lua
    │   └── options.lua
    ├── plugins/
    │   ├── autopairs.lua
    │   ├── lsp/
    │   │   ├── setup.lua        # Exclude jdtls from here
    │   │   └── java.lua         # Plugin specification
    │   ├── themes/
    │   │   └── kanagawa.lua
    │   └── treesitter.lua
    └── util/
        └── path.lua             # Cross-platform path utilities
```

## File Contents

### 1. util/path.lua

```lua
local M = {}

---@return string sep
function M.sep()
  return package.config:sub(1, 1)
end

---@param ... string
---@return string
function M.join(...)
  local s = M.sep()
  return table.concat({ ... }, s)
end

---@param patterns string[] list of glob patterns
---@return string[] matches de-duplicated
function M.multiglob(patterns)
  local seen, out = {}, {}
  for _, pat in ipairs(patterns) do
    local matches = vim.split(vim.fn.glob(pat, true), "\n", { trimempty = true })
    for _, m in ipairs(matches) do
      if m ~= "" and not seen[m] and vim.uv.fs_stat(m) then
        seen[m] = true
        table.insert(out, m)
      end
    end
  end
  return out
end

return M
```

### 2. plugins/lsp/java.lua

```lua
---@diagnostic disable: undefined-field
return {
  {
    -- JDTLS extensions (don't let mason-lspconfig manage this server)
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      -- Optional: DAP for Java debug + test discovery (strongly recommended)
      { "mfussenegger/nvim-dap", lazy = true },
      { "rcarriga/nvim-dap-ui",  lazy = true, opts = {} },
      { "theHamsta/nvim-dap-virtual-text", lazy = true, opts = {} },
    },
    init = function()
      -- absolutely ensure no global enable() for jdtls elsewhere:
      -- if you used vim.lsp.enable("jdtls") anywhere, remove it.
    end,
  },
}
```

### 3. ftplugin/java.lua (The Core Configuration)

```lua
-- ftplugin/java.lua — 2025 modern jdtls bootstrap
-- Requirements:
--   • Java 21+ on PATH (or JAVA_HOME) to run eclipse.jdt.ls
--   • eclipse.jdt.ls installed (jdtls wrapper preferred)
--   • Optional: java-debug & vscode-java-test bundles for DAP + test UX

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
  vim.notify("[jdtls] plugin not found", vim.log.levels.WARN)
  return
end

local Path = require("util.path")

-- ───────────────────────────────────────────────────────────────────────────────
-- Project root detection (Git > Gradle > Maven)
-- ───────────────────────────────────────────────────────────────────────────────
local root = vim.fs.root(0, { ".git", "gradlew", "mvnw", "pom.xml", "build.gradle", "settings.gradle" })
if not root then
  -- still allow standalone files (reduced features)
  root = vim.fn.getcwd()
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Workspace data dir (persistent indexing → faster subsequent opens)
--   ~/.local/share/jdtls/workspace/<foldername>
-- ───────────────────────────────────────────────────────────────────────────────
local project_name = vim.fn.fnamemodify(root, ":p:h:t")
local workspace = Path.join(vim.fn.stdpath("data"), "jdtls", "workspace", project_name)
vim.fn.mkdir(workspace, "p")

-- ───────────────────────────────────────────────────────────────────────────────
-- Bundles (optional): java-debug + vscode-java-test jars auto-discovery
-- Adjust the patterns if you store them elsewhere.
-- ───────────────────────────────────────────────────────────────────────────────
local home = vim.loop.os_homedir()
local bundle_patterns = {
  -- mason typical paths (if you happen to use mason for *bundles only*)
  Path.join(home, ".local", "share", "nvim", "mason", "packages", "java-debug-adapter", "extension", "server", "com.microsoft.java.debug.plugin-*.jar"),
  Path.join(home, ".local", "share", "nvim", "mason", "packages", "java-test",          "extension", "server", "*.jar"),

  -- manual clones/builds
  Path.join(home, "dev", "java-debug", "com.microsoft.java.debug.plugin", "target", "com.microsoft.java.debug.plugin-*.jar"),
  Path.join(home, "dev", "vscode-java-test", "server", "*.jar"),

  -- open-vsx unzips (if you unpacked VSCode extensions)
  Path.join(home, ".local", "share", "java", "vscode-java-debug", "extension", "server", "com.microsoft.java.debug.plugin-*.jar"),
  Path.join(home, ".local", "share", "java", "vscode-java-test",  "server", "*.jar"),
}

local bundles = require("util.path").multiglob(bundle_patterns)
-- prune unneeded java-test payloads to speed attach
local excluded = {
  ["com.microsoft.java.test.runner-jar-with-dependencies.jar"] = true,
  ["jacocoagent.jar"] = true,
}
do
  local filtered = {}
  for _, jar in ipairs(bundles) do
    local base = vim.fn.fnamemodify(jar, ":t")
    if not excluded[base] then
      table.insert(filtered, jar)
    end
  end
  bundles = filtered
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Capabilities & flags (performance-sane defaults)
-- ───────────────────────────────────────────────────────────────────────────────
local capabilities = vim.lsp.protocol.make_client_capabilities()
-- if you use cmp_nvim_lsp, uncomment:
-- capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local flags = {
  allow_incremental_sync = true,
  debounce_text_changes  = 80,
}

-- ───────────────────────────────────────────────────────────────────────────────
-- On_attach: maps + organize imports on save + DAP wiring
-- ───────────────────────────────────────────────────────────────────────────────
local function on_attach(client, bufnr)
  -- Basic LSP keymaps (short & standard)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map("n", "gd", vim.lsp.buf.definition, "Go to definition")
  map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
  map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
  map("n", "gr", vim.lsp.buf.references, "References")
  map("n", "K",  vim.lsp.buf.hover, "Hover")
  map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
  map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>fm", function() vim.lsp.buf.format({ async = true }) end, "Format")

  -- jdtls extras
  map("n", "<A-o>", jdtls.organize_imports, "Organize imports")
  map("n", "<leader>tc", jdtls.test_class, "Test class (DAP)")
  map("n", "<leader>tn", jdtls.test_nearest_method, "Test nearest (DAP)")
  map("n", "gS", jdtls.super_implementation, "Super implementation")

  -- Auto: organize imports + format on save (tweak if too aggressive)
  local aug = vim.api.nvim_create_augroup("JdtlsJavaFmt", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = aug,
    buffer = bufnr,
    callback = function()
      pcall(jdtls.organize_imports)
      vim.lsp.buf.format({ async = false, timeout_ms = 1500 })
    end,
  })

  -- DAP wiring (if nvim-dap present)
  pcall(jdtls.setup_dap, { hotcodereplace = "auto" })
  pcall(jdtls.setup_dap_main_class_configs)
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Java runtimes (so projects on 11/17/21+ work even if server runs on 21)
-- Adjust paths to your system JDKs as needed.
-- ───────────────────────────────────────────────────────────────────────────────
local java_home = os.getenv("JAVA_HOME") or ""
local runtimes = {
  -- Example set; keep names from the official ExecutionEnvironment enum
  { name = "JavaSE-17", path = "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" },
  { name = "JavaSE-21", path = java_home ~= "" and java_home or "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home" },
}

-- ───────────────────────────────────────────────────────────────────────────────
-- Settings tuned for Spring + enterprise builds
-- ───────────────────────────────────────────────────────────────────────────────
local settings = {
  java = {
    signatureHelp = { enabled = true },
    contentProvider = { preferred = "fernflower" }, -- good decompiler UX
    completion = {
      favoriteStaticMembers = {
        "org.assertj.core.api.Assertions.*",
        "org.mockito.Mockito.*",
        "org.mockito.BDDMockito.*",
        "org.mockito.ArgumentMatchers.*",
        "org.hamcrest.MatcherAssert.*",
        "org.hamcrest.Matchers.*",
        "java.util.Objects.requireNonNull",
        "java.util.Objects.requireNonNullElse",
      },
      filteredTypes = { "java.awt.*", "com.sun.*" }, -- trim noisy suggestions
    },
    sources = {
      organizeImports = {
        starThreshold = 999,  -- prefer explicit imports in Spring projects
        staticStarThreshold = 999,
      },
    },
    format = {
      -- Tip: point this to your org formatter if you use one
      enabled = true,
      settings = {
        -- url = "file:/path/to/eclipse-formatter.xml",
        -- profile = "YourProfileName",
      },
    },
    codeGeneration = {
      toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
      hashCodeEquals = { useJava7Objects = true },
      useBlocks = true,
    },
    configuration = {
      runtimes = runtimes,
      updateBuildConfiguration = "interactive", -- prompt to import changes
    },
    maven = {
      downloadSources = true,
      updateSnapshots = true,
    },
    eclipse = {
      downloadSources = true,
    },
    referencesCodeLens = { enabled = true },
    implementationsCodeLens = { enabled = true },
    inlayHints = { parameterNames = { enabled = "literals" } },
  },
}

-- ───────────────────────────────────────────────────────────────────────────────
-- Command: prefer the `jdtls` wrapper if present, else raw `java ...`
-- If you built/installed eclipse.jdt.ls differently, adjust `cmd`.
-- ───────────────────────────────────────────────────────────────────────────────
local function find_cmd()
  if vim.fn.executable("jdtls") == 1 then
    return { "jdtls", "-configuration", Path.join(vim.fn.stdpath("cache"), "jdtls"), "-data", workspace }
  end

  -- Fallback: assemble java -jar invocation (update paths to your install)
  local jdtls_base = Path.join(home, ".local", "share", "jdtls")         -- <- set yours
  local launcher = vim.fn.glob(Path.join(jdtls_base, "plugins", "org.eclipse.equinox.launcher_*.jar"))
  local config   = (vim.loop.os_uname().sysname == "Darwin") and "config_mac" or "config_linux"

  return {
    "java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.level=WARN",
    "-Xmx2G",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher,
    "-configuration", Path.join(jdtls_base, config),
    "-data", workspace,
  }
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Final config & start/attach
-- ───────────────────────────────────────────────────────────────────────────────
local config = {
  name = "jdtls",
  cmd = find_cmd(),
  root_dir = root,
  capabilities = capabilities,
  flags = flags,
  settings = settings,
  init_options = {
    bundles = bundles, -- empty if you didn't install debug/test; that's fine
  },
}

jdtls.start_or_attach(config)
```

### 4. plugins/lsp/setup.lua (Updated)

```lua
-- Make sure this file does NOT include jdtls
-- Example:
return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")

      -- Configure other servers (but NOT jdtls)
      -- lspconfig.lua_ls.setup{ ... }
      -- lspconfig.tsserver.setup{ ... }
      -- lspconfig.pyright.setup{ ... }

      -- DO NOT: vim.lsp.enable("jdtls")
      -- DO NOT: lspconfig.jdtls.setup(...)
    end,
  },
}
```

## Installation Instructions

1. **Install Java 21+**: Required to run the language server
2. **Install JDTLS**: `brew install jdtls` or download manually
3. **Optional - Install debug tools via Mason**:
   ```vim
   :Mason
   # Install: java-debug-adapter, java-test
   ```
4. **Set Java paths** (recommended):
   ```bash
   export JAVA_HOME=/path/to/jdk-21
   export JAVA_17_HOME=/path/to/jdk-17  # if targeting Java 17
   ```

## Key Features

- ✅ **Professional architecture** with proper separation of concerns
- ✅ **Spring Boot optimized** completions and imports
- ✅ **Fast startup** with persistent workspaces
- ✅ **Full debugging support** with DAP integration
- ✅ **Auto-formatting** and import organization
- ✅ **Multi-JDK support** for different project targets
- ✅ **Enterprise ready** for large codebases
- ✅ **Cross-platform** compatibility

This configuration provides the most professional, maintainable, and performant JDTLS setup for serious Java/Spring development work.

---

DEEPSEEK SAID THIS ONE WON 

After reviewing all samples, I'll create a professional jdtls setup that combines the best elements from each while ensuring optimal performance and features. Here's my implementation:

## Final Tree Structure
```
~/.config/nvim/
├── init.lua
├── lazy-lock.json
└── lua/
    ├── config/
    │   └── lazy.lua
    ├── core/
    │   ├── diagnostics.lua
    │   ├── globals.lua
    │   ├── jdtls.lua          # Main JDTLS configuration
    │   └── options.lua
    ├── plugins/
    │   ├── autopairs.lua
    │   ├── lsp/
    │   │   ├── setup.lua
    │   │   └── java.lua       # Plugin spec for nvim-jdtls
    │   ├── themes/
    │   │   └── kanagawa.lua
    │   └── treesitter.lua
    └── util/
        └── path.lua           # Cross-platform path utilities
```

## 1. `lua/util/path.lua`
```lua
local M = {}

function M.sep()
  return package.config:sub(1, 1)
end

function M.join(...)
  return table.concat({...}, M.sep())
end

function M.multiglob(patterns)
  local seen, out = {}, {}
  for _, pat in ipairs(patterns) do
    local matches = vim.split(vim.fn.glob(pat, true), "\n", { trimempty = true })
    for _, m in ipairs(matches) do
      if m ~= "" and not seen[m] and vim.uv.fs_stat(m) then
        seen[m] = true
        table.insert(out, m)
      end
    end
  end
  return out
end

return M
```

## 2. `lua/plugins/lsp/java.lua`
```lua
return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
      -- Optional debugging dependencies
      { "mfussenegger/nvim-dap", lazy = true },
      { "rcarriga/nvim-dap-ui", lazy = true },
      { "theHamsta/nvim-dap-virtual-text", lazy = true },
    },
    config = function()
      require("core.jdtls").setup()
    end,
  },
}
```

## 3. `lua/core/jdtls.lua`
```lua
local M = {}
local Path = require("util.path")

function M.setup()
  local jdtls_ok, jdtls = pcall(require, "jdtls")
  if not jdtls_ok then
    vim.notify("JDTLS not available", vim.log.levels.WARN)
    return
  end

  -- Root directory detection
  local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "settings.gradle" }
  local root_dir = require("jdtls.setup").find_root(root_markers) or vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
  
  -- Workspace directory
  local workspace_dir = Path.join(vim.fn.stdpath("data"), "jdtls", "workspace", project_name)
  vim.fn.mkdir(workspace_dir, "p")

  -- Detect OS and set config directory
  local os_config = vim.loop.os_uname().sysname == "Darwin" and "config_mac" or "config_linux"
  local jdtls_path = Path.join(vim.fn.stdpath("data"), "mason", "packages", "jdtls")
  local config_dir = Path.join(jdtls_path, os_config)

  -- Find launcher jar
  local launcher_jar = vim.fn.glob(Path.join(jdtls_path, "plugins", "org.eclipse.equinox.launcher_*.jar"))
  if launcher_jar == "" then
    vim.notify("JDTLS launcher not found", vim.log.levels.ERROR)
    return
  end

  -- Java command setup
  local java_cmd = os.getenv("JAVA_HOME") and Path.join(os.getenv("JAVA_HOME"), "bin", "java") or "java"
  
  -- Bundles for debugging
  local bundles = {}
  local debug_bundle = Path.join(vim.fn.stdpath("data"), "mason", "packages", "java-debug-adapter", "extension", "server", "com.microsoft.java.debug.plugin-*.jar")
  local test_bundle = Path.join(vim.fn.stdpath("data"), "mason", "packages", "java-test", "extension", "server", "*.jar")
  
  local bundle_patterns = {
    debug_bundle,
    test_bundle,
    -- Additional bundle locations can be added here
  }
  
  bundles = Path.multiglob(bundle_patterns)

  -- Capabilities
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if cmp_ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  -- Settings
  local settings = {
    java = {
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" },
      completion = {
        favoriteStaticMembers = {
          "org.junit.jupiter.api.Assertions.*",
          "org.mockito.Mockito.*",
          "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
          "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
        },
        filteredTypes = {
          "com.sun.*",
          "io.micrometer.shaded.*",
          "java.awt.*",
          "jdk.*",
          "sun.*",
        },
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
        },
        useBlocks = true,
      },
      configuration = {
        runtimes = M.get_java_runtimes(),
        updateBuildConfiguration = "interactive",
      },
      format = {
        enabled = true,
        settings = {
          url = Path.join(vim.fn.stdpath("config"), "eclipse-java-spring-style.xml"),
          profile = "SpringStyle",
        },
      },
    },
  }

  -- Command
  local cmd = {
    java_cmd,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xmx2g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher_jar,
    "-configuration", config_dir,
    "-data", workspace_dir,
  }

  -- On attach function
  local on_attach = function(client, bufnr)
    -- Standard LSP mappings
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs { buffer = bufnr, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "K", vim.lsp.buf.hover, "Hover")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>fm", function() vim.lsp.buf.format({ async = true }) end, "Format")

    -- JDTLS specific mappings
    map("n", "<leader>jo", jdtls.organize_imports, "Organize imports")
    map("n", "<leader>jtc", jdtls.test_class, "Test class")
    map("n", "<leader>jtn", jdtls.test_nearest_method, "Test nearest method")
    map("v", "<leader>jev", jdtls.extract_variable, "Extract variable")
    map("v", "<leader>jem", jdtls.extract_method, "Extract method")

    -- Setup DAP if available
    pcall(function()
      jdtls.setup_dap({ hotcodereplace = "auto" })
      jdtls.setup_dap_main_class_configs()
    end)

    -- Auto format and organize imports on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        pcall(jdtls.organize_imports)
        vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
      end,
    })
  end

  -- Final config
  local config = {
    cmd = cmd,
    root_dir = root_dir,
    settings = settings,
    capabilities = capabilities,
    on_attach = on_attach,
    init_options = {
      bundles = bundles,
    },
    flags = {
      allow_incremental_sync = true,
      debounce_text_changes = 80,
    },
  }

  jdtls.start_or_attach(config)
end

function M.get_java_runtimes()
  local runtimes = {}
  local java_homes = {
    os.getenv("JAVA_HOME"),
    os.getenv("JAVA_8_HOME"),
    os.getenv("JAVA_11_HOME"),
    os.getenv("JAVA_17_HOME"),
    os.getenv("JAVA_21_HOME"),
  }

  for _, home in ipairs(java_homes) do
    if home and vim.fn.isdirectory(home) == 1 then
      local version = M.get_java_version(home)
      if version then
        table.insert(runtimes, {
          name = "JavaSE-" .. version,
          path = home,
        })
      end
    end
  end

  return runtimes
end

function M.get_java_version(java_home)
  local java_bin = Path.join(java_home, "bin", "java")
  if vim.fn.executable(java_bin) ~= 1 then
    return nil
  end

  local handle = io.popen(java_bin .. " -version 2>&1")
  if not handle then return nil end
  
  local output = handle:read("*a")
  handle:close()

  local version = output:match('version "(%d+).%d+.%d+[_%d]*"')
  return version
end

return M
```

## 4. Eclipse Formatter Configuration
Create `eclipse-java-spring-style.xml` in your config directory:
```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles version="20">
<profile kind="CodeFormatterProfile" name="SpringStyle" version="20">
<setting id="org.eclipse.jdt.core.formatter.insert_space_after_comma_in_annotation" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_comma_in_annotation" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_block" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_anonymous_type_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_comma_in_multiple_field_declarations" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_after_comma_in_multiple_field_declarations" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_between_empty_brackets" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_array_initializer" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_after_opening_brace_in_array_initializer" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_closing_brace_in_array_initializer" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_new_line_in_empty_annotation_declaration" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_new_line_in_empty_type_declaration" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_new_line_before_closing_brace_in_array_initializer" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_between_empty_parens_in_annotation_type_member_declaration" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_annotation" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_annotation_type_member_declaration" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.comment.line_length" value="120"/>
<setting id="org.eclipse.jdt.core.formatter.lineSplit" value="120"/>
<setting id="org.eclipse.jdt.core.formatter.tabulation.size" value="4"/>
<setting id="org.eclipse.jdt.core.formatter.tabulation.char" value="space"/>
<setting id="org.eclipse.jdt.core.formatter.indentation.size" value="4"/>
<setting id="org.eclipse.jdt.core.formatter.continuation_indentation" value="2"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_allocation_expression" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_enum_constant" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_explicit_constructor_call" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_method_invocation" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_qualified_allocation_expression" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_assignment" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_binary_expression" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_compact_loops" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_conditional_expression" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_enum_constants" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_expressions_in_array_initializer" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_method_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_multiple_fields" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_parameters_in_constructor_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_parameters_in_method_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_resources_in_try" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_superclass_in_type_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_superinterfaces_in_type_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_throws_clause_in_constructor_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_throws_clause_in_method_declaration" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_union_type_in_multicatch" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_after_imports" value="1"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_before_first_class_body_declaration" value="0"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_before_imports" value="1"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_before_member_type" value="1"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_before_package" value="0"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_between_import_groups" value="1"/>
<setting id="org.eclipse.jdt.core.formatter.blank_lines_between_type_declarations" value="1"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_annotation_type_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_array_initializer" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_block" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_block_in_case" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_constructor_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_enum_constant" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_enum_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_method_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_switch" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_type_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.comment.clear_blank_lines_in_block_comment" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.comment.clear_blank_lines_in_javadoc_comment" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.comment.format_javadoc_comments" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.comment.indent_parameter_description" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.comment.indent_root_tags" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.comment.insert_new_line_before_root_tags" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.comment.insert_new_line_for_parameter" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.comment.new_lines_at_javadoc_boundaries" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.comment.preserve_white_space_between_code_and_comments" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.compact_else_if" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.continuation_indentation_for_array_initializer" value="2"/>
<setting id="org.eclipse.jdt.core.formatter.format_guardian_clause_on_one_line" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.format_line_comment_starting_on_first_column" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_type_header" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_breaks_compare_to_cases" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_empty_lines" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.indent_statements_compare_to_block" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_statements_compare_to_body" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_cases" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_switch" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.join_wrapped_lines" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.keep_else_statement_on_same_line" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.keep_empty_array_initializer_on_one_line" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.keep_imple_if_on_one_line" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.keep_then_statement_on_same_line" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.never_indent_block_comments_on_first_column" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.never_indent_line_comments_on_first_column" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.put_empty_statement_on_new_line" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.tabulation.char" value="space"/>
<setting id="org.eclipse.jdt.core.formatter.use_on_off_tags" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.use_tabs_only_for_leading_indentations" value="false"/>
<setting id="org.eclipse.jdt.core.formatter.wrap_before_binary_operator" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.wrap_before_conditional_operator" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.wrap_before_else_operator" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.wrap_outer_expressions_when_nested" value="true"/>
</profile>
</profiles>
```

## Installation Instructions

1. Install required Mason packages:
   ```vim
   :MasonInstall jdtls java-debug-adapter java-test
   ```

2. Set JAVA_HOME environment variable to point to your JDK (21+ recommended)

3. For Spring projects, add these dependencies to your build file:
   - Spring Boot Starter Web
   - Spring Boot Starter Test

This setup provides:
- Professional Java development environment
- Spring Boot support with proper formatting
- Debugging and testing capabilities
- Optimized performance for large projects
- Clean code organization and maintainability
- Cross-platform compatibility

The configuration is designed to be both feature-rich and performant, following best practices for professional Java development in Neovim.

---

GROK SAID THIS ONE WON 

## Analysis and Decision

After a thorough analysis of the provided samples (A through E) and extensive research into the state of Neovim Java development setups as of September 2025, I've evaluated each one based on your criteria: professional structure (clean, standard, aligned with experienced software engineers), optimization (performance, smoothness), feature-packed without overload (DAP, tests, Spring support, keymaps, formatting, but no bloat), buttery smooth operation (fast attach, incremental sync, minimal lag), and uniqueness (advanced features like dynamic detection, snippets, env flexibility).

### Quick Breakdown of Samples
- **Sample A**: Clean and standard ftplugin approach (recommended by nvim-jdtls repo). Good separation, performance tweaks (debounce, incremental sync), auto-bundle detection, Spring-friendly completions. Balanced, but runtimes are hardcoded, no dynamic detection, and limited Spring depth (no dedicated tools or snippets). Solid for basics, but not the most feature-packed.
- **Sample B**: Functional, but less professional—hardcoded Linux paths, duplicated setup calls (in init.lua and setup.lua), less flexible runtimes. Includes Lombok and DAP, but feels clunky and not optimized for cross-OS or large projects. Not unique.
- **Sample C**: Most comprehensive among the samples. Dynamic runtimes (SDKMAN support, common paths), OS detection, performance JVM args, Spring-specific root markers/completions/snippets, user commands (compile, jshell, etc.), enhanced completion with icons, project type detection, format-on-save with Spring XML profile. Feature-packed and unique without overload (organized into modules). Closest to "professional architect" level, but lacks automatic Spring Boot Language Server integration (a key 2025 standard for Spring devs).
- **Sample D**: Incomplete XML formatter profile. Not a full setup—disqualifies it.
- **Sample E**: Lean and env-aware (JAVA_XX_HOME, SPRING_TOOLS_JAR_DIR), mason-flexible, good utils. Optimized for speed/large repos, optional Spring bundles. Professional and smooth, but less feature-packed than C (no snippets, user commands, project detection).

Among A-E, **Sample C is the best**. It's the most professional, optimized, and feature-packed without bloat—tailored for Spring with unique extras like snippets and dynamic everything. It aligns with niche pro engineers who want control and depth. A and E are close runners-up for simplicity, but C edges out with its uniqueness and completeness.

### Research Insights
I searched web and X for "best nvim-jdtls setup for Java Spring Neovim 2025", browsed nvim-jdtls and nvim-java repos, and checked related GitHub issues/Reddit/YouTube (e.g., recent 2025 videos on Java in Neovim). Key findings:
- Direct nvim-jdtls (as in samples) is standard and KISS, but for Spring, the community recommends wrappers like nvim-java (built on nvim-jdtls) for painless auto-install of dependencies (jdtls, debug, test, Lombok, Spring Boot Tools).
- nvim-java adds unique Spring Boot Language Server support out of the box (e.g., boot properties autocompletion, live reload hints), realtime settings via neoconf, and automatic everything—making it "buttery smooth" and feature-packed for 2025 pro setups.
- Reddit/X discussions (2024-2025) praise nvim-java for Spring over direct configs, as it avoids manual jar hunting/bundle globs. Direct setups like C are great but require extra work for full Spring LS.
- To super-optimize C, I incorporated nvim-java-inspired improvements: Auto Spring Boot LS bundle, better cross-OS flexibility, and minor smoothness tweaks (e.g., async format timeout).

The result is an enhanced version of Sample C: Full Spring support, dynamic, professional, smooth. If you prefer direct nvim-jdtls without nvim-java, we can revert.

## eza -T (Resulting Layout)
```
~/.config/nvim
├── init.lua
├── lazy-lock.json
└── lua
    ├── config
    │ └── lazy.lua
    ├── core
    │ ├── diagnostics.lua
    │ ├── globals.lua
    │ └── options.lua
    ├── plugins
    │ ├── autopairs.lua
    │ ├── lsp
    │ │ ├── setup.lua  # Modified to exclude jdtls (handled separately)
    │ │ └── java.lua   # New: Plugin spec for nvim-jdtls + extras
    │ ├── themes
    │ │ └── kanagawa.lua
    │ └── treesitter.lua
    └── ftplugin
        └── java.lua   # New: Core bootstrap + on_attach
```

> Create `ftplugin/` if missing. The XML formatter goes in `~/.config/nvim/eclipse-java-style.xml`.

## 1) plugins/lsp/java.lua (Plugin Spec + Module for Extras)
**Path:** `~/.config/nvim/lua/plugins/lsp/java.lua`

```lua
-- lua/plugins/lsp/java.lua: Enhanced Java LSP module with Spring optimizations

local M = {}

-- Java-specific diagnostics config
M.jdtls_config = {
  diagnostics = {
    enable = true,
    signs = {
      { name = "DiagnosticSignError", text = "❌" },
      { name = "DiagnosticSignWarn", text = "⚠️" },
      { name = "DiagnosticSignHint", text = "💡" },
      { name = "DiagnosticSignInfo", text = "ℹ️" },
    },
    virtual_text = {
      enabled = true,
      spacing = 4,
      source = "if_many",
      prefix = "●",
    },
    severity_sort = true,
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
  },
  -- Spring Boot specific completions
  spring = {
    completions = {
      "org.springframework.web.bind.annotation.*",
      "org.springframework.boot.autoconfigure.*",
      "org.springframework.context.annotation.*",
      "org.springframework.stereotype.*",
      "org.springframework.data.jpa.repository.*",
      "org.springframework.security.config.annotation.web.builders.*",
      "org.springframework.transaction.annotation.*",
    },
  },
}

-- Setup diagnostics signs
function M.setup_diagnostics()
  for _, sign in ipairs(M.jdtls_config.diagnostics.signs) do
    vim.fn.sign_define(sign.name, {
      texthl = sign.name,
      text = sign.text,
      numhl = "",
    })
  end
  vim.diagnostic.config({
    virtual_text = M.jdtls_config.diagnostics.virtual_text,
    signs = M.jdtls_config.diagnostics.enable,
    underline = true,
    update_in_insert = false,
    severity_sort = M.jdtls_config.diagnostics.severity_sort,
    float = M.jdtls_config.diagnostics.float,
  })
end

-- Detect project type (for notifications or custom logic)
function M.detect_project_type()
  local cwd = vim.fn.getcwd()
  local spring_indicators = {
    "src/main/java/**/Application.java",
    "src/main/java/**/*Application.java",
    "application.properties",
    "application.yml",
    "application.yaml",
  }
  for _, pattern in ipairs(spring_indicators) do
    if vim.fn.glob(cwd .. "/" .. pattern) ~= "" then
      return "spring-boot"
    end
  end
  if vim.fn.filereadable(cwd .. "/pom.xml") == 1 then
    return "maven"
  end
  if vim.fn.filereadable(cwd .. "/build.gradle") == 1 or vim.fn.filereadable(cwd .. "/build.gradle.kts") == 1 then
    return "gradle"
  end
  return "standalone"
end

-- Enhanced completion for Java with CMP
function M.setup_completion()
  local cmp = require('cmp')
  local java_cmp_config = {
    snippet = {
      expand = function(args)
        vim.fn["vsnip#anonymous"](args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        else
          fallback()
        end
      end, { 'i', 's' }),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp', priority = 1000 },
      { name = 'vsnip', priority = 900 },
      { name = 'buffer', priority = 800 },
      { name = 'path', priority = 700 },
    }),
    formatting = {
      fields = { "kind", "abbr", "menu" },
      format = function(entry, vim_item)
        local kind_icons = {
          Text = "",
          Method = "󰆧",
          Function = "󰊕",
          Constructor = "",
          Field = "󰇽",
          Variable = "󰂡",
          Class = "󰠱",
          Interface = "",
          Module = "",
          Property = "󰜢",
          Unit = "",
          Value = "󰎠",
          Enum = "",
          Keyword = "󰌋",
          Snippet = "",
          Color = "󰏘",
          File = "󰈙",
          Reference = "",
          Folder = "󰉋",
          EnumMember = "",
          Constant = "󰏿",
          Struct = "",
          Event = "",
          Operator = "󰆕",
          TypeParameter = "󰅲",
        }
        vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind)
        vim_item.menu = ({
          nvim_lsp = "[LSP]",
          vsnip = "[Snip]",
          buffer = "[Buf]",
          path = "[Path]",
        })[entry.source.name]
        return vim_item
      end,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
  }
  cmp.setup.filetype('java', java_cmp_config)
end

-- Create Spring Boot snippets
function M.create_spring_snippets()
  local snippets_dir = vim.fn.stdpath("config") .. "/snippets"
  vim.fn.mkdir(snippets_dir, "p")
  local java_snippets = {
    controller = [[
@RestController
@RequestMapping("/${1:api}")
public class ${2:Controller} {
    @Autowired
    private ${3:Service} ${4:service};
    @GetMapping
    public ResponseEntity<List<${5:Entity}>> getAll() {
        return ResponseEntity.ok(${4:service}.findAll());
    }
    @GetMapping("/{id}")
    public ResponseEntity<${5:Entity}> getById(@PathVariable Long id) {
        return ResponseEntity.ok(${4:service}.findById(id));
    }
    @PostMapping
    public ResponseEntity<${5:Entity}> create(@RequestBody ${5:Entity} ${6:entity}) {
        return ResponseEntity.ok(${4:service}.save(${6:entity}));
    }
}]],
    service = [[
@Service
@Transactional
public class ${1:Service} {
    @Autowired
    private ${2:Repository} ${3:repository};
    public List<${4:Entity}> findAll() {
        return ${3:repository}.findAll();
    }
    public ${4:Entity} findById(Long id) {
        return ${3:repository}.findById(id)
            .orElseThrow(() -> new RuntimeException("${4:Entity} not found"));
    }
    public ${4:Entity} save(${4:Entity} ${5:entity}) {
        return ${3:repository}.save(${5:entity});
    }
}]],
    entity = [[
@Entity
@Table(name = "${1:table_name}")
public class ${2:EntityName} {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false)
    private String ${3:field};
    // Constructors
    public ${2:EntityName}() {}
    public ${2:EntityName}(String ${3:field}) {
        this.${3:field} = ${3:field};
    }
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String get${3/(.)/\u$1/}() { return ${3:field}; }
    public void set${3/(.)/\u$1/}(String ${3:field}) { this.${3:field} = ${3:field}; }
}]],
  }
  local snippets_file = io.open(snippets_dir .. "/java.json", "w")
  if snippets_file then
    snippets_file:write(vim.json.encode(java_snippets))
    snippets_file:close()
  end
end

-- Java keymaps setup
function M.setup_java_keymaps()
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = 0, desc = desc })
  end
  -- Testing
  map("n", "<leader>tc", "<cmd>lua require('jdtls.dap').test_class()<CR>", "Test Class")
  map("n", "<leader>tm", "<cmd>lua require('jdtls.dap').test_nearest_method()<CR>", "Test Method")
  map("n", "<leader>tp", "<cmd>lua require('jdtls.dap').pick_test()<CR>", "Pick Test")
  -- Build
  map("n", "<leader>bc", "<cmd>JdtCompile<CR>", "Compile")
  map("n", "<leader>bf", "<cmd>JdtCompile full<CR>", "Full Compile")
  map("n", "<leader>bu", "<cmd>JdtUpdateConfig<CR>", "Update Config")
  -- Navigation
  map("n", "<leader>jo", "<cmd>lua require('jdtls').organize_imports()<CR>", "Organize Imports")
  map("n", "<leader>jc", "<cmd>JdtBytecode<CR>", "Show Bytecode")
  map("n", "<leader>js", "<cmd>JdtJshell<CR>", "Open JShell")
end

-- Full module setup
function M.setup()
  M.setup_diagnostics()
  M.setup_completion()
  M.create_spring_snippets()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = M.setup_java_keymaps,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      local project_type = M.detect_project_type()
      vim.notify("Detected project type: " .. project_type, vim.log.levels.INFO)
    end,
  })
end

return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      require("plugins.lsp.java").setup()
    end,
  },
}
```

## 2) ftplugin/java.lua (Bootstrap + On Attach)
**Path:** `~/.config/nvim/ftplugin/java.lua`

```lua
-- ftplugin/java.lua: Professional JDTLS bootstrap for Spring/Java

local jdtls = require('jdtls')
local jdtls_dap = require('jdtls.dap')

-- OS detection
local function get_os()
  local handle = io.popen('uname')
  local result = handle:read("*a"):lower():gsub("%s+", "")
  handle:close()
  return result
end

local os_name = get_os()
local home_dir = os.getenv("HOME")
local workspace_root = home_dir .. "/.local/share/eclipse.jdt.ls/workspace/"
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace_dir = workspace_root .. project_name

-- JDTLS paths (mason or manual)
local jdtls_path = home_dir .. "/.local/share/nvim/mason/packages/jdtls"  -- Adjust if manual
local lombok_path = jdtls_path .. "/lombok.jar"
local config_dir = jdtls_path .. "/config_" .. (os_name == "darwin" and "mac" or os_name)

-- Launcher JAR
local function find_launcher_jar()
  local launcher_pattern = jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"
  local matches = vim.fn.glob(launcher_pattern, false, true)
  if #matches > 0 then
    table.sort(matches)
    return matches[#matches]
  end
  error("Launcher JAR not found in " .. jdtls_path .. "/plugins/")
end

-- Dynamic Java runtimes
local function get_java_runtimes()
  local runtimes = {}
  local java_paths = {
    ["/usr/lib/jvm/java-8-openjdk"] = "JavaSE-1.8",
    ["/usr/lib/jvm/java-11-openjdk"] = "JavaSE-11",
    ["/usr/lib/jvm/java-17-openjdk"] = "JavaSE-17",
    ["/usr/lib/jvm/java-21-openjdk"] = "JavaSE-21",
    ["/opt/homebrew/Cellar/openjdk@8"] = "JavaSE-1.8",
    ["/opt/homebrew/Cellar/openjdk@11"] = "JavaSE-11",
    ["/opt/homebrew/Cellar/openjdk@17"] = "JavaSE-17",
    ["/opt/homebrew/Cellar/openjdk@21"] = "JavaSE-21",
    [home_dir .. "/.sdkman/candidates/java"] = nil,
  }
  for path, env in pairs(java_paths) do
    if vim.fn.isdirectory(path) == 1 and env then
      table.insert(runtimes, { name = env, path = path })
    end
  end
  local sdkman_java_dir = home_dir .. "/.sdkman/candidates/java"
  if vim.fn.isdirectory(sdkman_java_dir) == 1 then
    local java_versions = vim.fn.readdir(sdkman_java_dir)
    for _, version in ipairs(java_versions) do
      local version_path = sdkman_java_dir .. "/" .. version
      if vim.fn.isdirectory(version_path) == 1 then
        local env_name = "JavaSE-" .. string.match(version, "(%d+)")
        if env_name and env_name ~= "JavaSE-" then
          table.insert(runtimes, { name = env_name, path = version_path })
        end
      end
    end
  end
  return runtimes
end

-- Bundles (DAP + Test + Spring Boot LS)
local function get_bundles()
  local bundles = {}
  -- Debug
  local debug_bundle_pattern = jdtls_path .. "/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar"
  vim.list_extend(bundles, vim.fn.glob(debug_bundle_pattern, false, true))
  -- Test
  local test_bundle_pattern = jdtls_path .. "/vscode-java-test/server/*.jar"
  local test_bundles = vim.fn.glob(test_bundle_pattern, false, true)
  local excluded = { "com.microsoft.java.test.runner-jar-with-dependencies.jar", "jacocoagent.jar" }
  for _, jar in ipairs(test_bundles) do
    local jar_name = vim.fn.fnamemodify(jar, ":t")
    if not vim.tbl_contains(excluded, jar_name) then
      table.insert(bundles, jar)
    end
  end
  -- Spring Boot LS (download from https://repo.spring.io/release/org/springframework/boot/spring-boot-language-server/ and add path)
  local spring_path = home_dir .. "/.local/share/nvim/java/spring-boot-ls/spring-boot-language-server-*.jar"  -- Adjust path
  vim.list_extend(bundles, vim.fn.glob(spring_path, false, true))
  return bundles
end

-- JVM args for performance
local function get_jvm_args()
  return {
    "-Xms1G",
    "-Xmx4G",
    "-XX:+UseG1GC",
    "-XX:G1HeapRegionSize=32m",
    "-XX:+UseG1MixedGCCountTarget=1",
    "-XX:+DisableExplicitGC",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "--add-opens", "java.base/sun.nio.fs=ALL-UNNAMED",
    vim.fn.filereadable(lombok_path) == 1 and ("-javaagent:" .. lombok_path) or nil,
  }
end

-- Root detection with Spring priority
local root_markers = {
  "application.properties", "application.yml", "application.yaml",
  "pom.xml", "gradlew", "gradle.properties", "build.gradle", "build.gradle.kts",
  ".git", ".project",
}
local root_dir = require('jdtls.setup').find_root(root_markers) or vim.fn.getcwd()

-- Config
local config = {
  name = "jdtls",
  cmd = vim.tbl_filter(function(arg) return arg ~= nil end, {
    "java",
    unpack(get_jvm_args()),
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Dfile.encoding=UTF-8",
    "-jar", find_launcher_jar(),
    "-configuration", config_dir,
    "-data", workspace_dir,
  }),
  root_dir = root_dir,
  settings = {
    java = {
      eclipse = { downloadSources = true },
      configuration = { updateBuildConfiguration = "automatic", runtimes = get_java_runtimes() },
      codeGeneration = {
        toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
        useBlocks = true,
        generateComments = true,
        insertLocation = "afterCursor",
      },
      completion = {
        favoriteStaticMembers = {
          "org.junit.jupiter.api.Assertions.*",
          "org.mockito.Mockito.*",
          "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
          "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
          "org.hamcrest.Matchers.*",
          "org.hamcrest.CoreMatchers.*",
          "java.util.Objects.requireNonNull",
          "java.util.Objects.requireNonNullElse",
          "java.util.Optional.*",
        },
        importOrder = { "java", "javax", "org", "com" },
        filteredTypes = { "com.sun.*", "sun.*" },
      },
      sources = { organizeImports = { starThreshold = 99, staticStarThreshold = 99 } },
      format = {
        settings = { url = vim.fn.stdpath("config") .. "/eclipse-java-style.xml", profile = "SpringProfile" },
        insertSpaces = true,
        tabSize = 4,
      },
      compile = { nullAnalysis = { mode = "automatic" } },
      saveActions = { organizeImports = true },
      contentProvider = { preferred = "fernflower" },
      maven = { downloadSources = true, updateSnapshots = false },
      implementationsCodeLens = { enabled = true },
      referencesCodeLens = { enabled = true },
      signatureHelp = { enabled = true, description = { enabled = true } },
      progressReports = { enabled = true },
      folding = { enabled = true },
      selectionRange = { enabled = true },
    },
  },
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
  init_options = {
    bundles = get_bundles(),
    workspaceFolders = vim.tbl_map(function(folder) return vim.uri_from_fname(folder) end, { root_dir }),
  },
  handlers = {
    ["$/progress"] = function(_, result, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client and client.name == "jdtls" then
        local value = result.value
        if value and value.kind == "end" then
          vim.notify("JDTLS: " .. (value.message or "Operation completed"), vim.log.levels.INFO)
        end
      end
    end,
  },
  on_attach = function(client, bufnr)
    local opts = { noremap = true, silent = true, buffer = bufnr }
    -- Standard LSP
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set("n", "<space>wl", function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, opts)
    vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "<space>f", function() vim.lsp.buf.format { async = true } end, opts)
    -- JDTLS extras
    vim.keymap.set("n", "<A-o>", jdtls.organize_imports, opts)
    vim.keymap.set("n", "crv", jdtls.extract_variable, opts)
    vim.keymap.set("v", "crv", function() jdtls.extract_variable(true) end, opts)
    vim.keymap.set("n", "crc", jdtls.extract_constant, opts)
    vim.keymap.set("v", "crc", function() jdtls.extract_constant(true) end, opts)
    vim.keymap.set("v", "crm", function() jdtls.extract_method(true) end, opts)
    vim.keymap.set("n", "<space>si", jdtls.super_implementation, opts)
    -- DAP
    if pcall(require, "dap") then
      vim.keymap.set("n", "<leader>df", jdtls_dap.test_class, opts)
      vim.keymap.set("n", "<leader>dn", jdtls_dap.test_nearest_method, opts)
      vim.keymap.set("n", "<leader>dp", jdtls_dap.pick_test, opts)
      jdtls_dap.setup_dap_main_class_configs()
    end
    -- Auto format/organize on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        pcall(jdtls.organize_imports)
        vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
      end,
    })
    vim.notify("JDTLS attached to buffer " .. bufnr, vim.log.levels.INFO)
  end,
  flags = {
    allow_incremental_sync = true,
    debounce_text_changes = 80,
  },
}

jdtls.start_or_attach(config)

-- User commands
vim.api.nvim_create_user_command("JdtCompile", function(opts)
  jdtls.compile(opts.args == "full" and "full" or "incremental")
end, { nargs = "?", complete = function() return { "full", "incremental" } end })
vim.api.nvim_create_user_command("JdtUpdateConfig", jdtls.update_project_config, {})
vim.api.nvim_create_user_command("JdtJol", jdtls.jol, {})
vim.api.nvim_create_user_command("JdtBytecode", jdtls.javap, {})
vim.api.nvim_create_user_command("JdtJshell", jdtls.jshell, {})
vim.api.nvim_create_user_command("JdtRestart", jdtls.restart, {})
```

## 3) eclipse-java-style.xml (Spring Formatter Profile)
**Path:** `~/.config/nvim/eclipse-java-style.xml`

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles version="18">
  <profile kind="CodeFormatterProfile" name="SpringProfile" version="18">
    <setting id="org.eclipse.jdt.core.formatter.insert_space_after_comma_in_annotation" value="insert"/>
    <setting id="org.eclipse.jdt.core.formatter.insert_space_before_comma_in_annotation" value="do not insert"/>
    <setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_block" value="insert"/>
    <setting id="org.eclipse.jdt.core.formatter.brace_position_for_anonymous_type_declaration" value="end_of_line"/>
    <setting id="org.eclipse.jdt.core.formatter.insert_space_before_comma_in_multiple_field_declarations" value="do not insert"/>
    <setting id="org.eclipse.jdt.core.formatter.insert_space_after_comma_in_multiple_field_declarations" value="insert"/>
    <setting id="org.eclipse.jdt.core.formatter.insert_space_between_empty_parentheses_in_constructor_declaration" value="do not insert"/>
    <setting id="org.eclipse.jdt.core.formatter.wrap_before_conditional_operator" value="true"/>
    <setting id="org.eclipse.jdt.core.formatter.wrap_before_or_operator_multicatch" value="true"/>
    <setting id="org.eclipse.jdt.core.formatter.wrap_outer_expressions_when_nested" value="true"/>
  </profile>
</profiles>
```

## 4) plugins/lsp/setup.lua (Modified to Exclude jdtls)
**Path:** `~/.config/nvim/lua/plugins/lsp/setup.lua`

```lua
-- lua/plugins/lsp/setup.lua: General LSP setup (exclude jdtls)

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lsp = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Configure other servers (e.g., from your existing)
      -- lsp.lua_ls.setup({ capabilities = capabilities })
      -- lsp.tsserver.setup({ capabilities = capabilities })

      -- Do NOT setup jdtls here; handled in ftplugin/java.lua
    end,
  },
}
```

### Setup Notes
- **Install Dependencies**: `:MasonInstall jdtls java-debug-adapter java-test lombok` (for bundles/Lombok). For Spring Boot LS, download `spring-boot-language-server-*.jar` from https://repo.spring.io/release/org/springframework/boot/spring-boot-language-server/ and place in `~/.local/share/nvim/java/spring-boot-ls/`.
- **Java Requirements**: JDK 21+ for jdtls, but runtimes support older for projects. Set SDKMAN if used.
- **Performance**: Debounce 80ms, incremental sync, G1GC JVM for smooth large projects.
- **Features**: DAP/debug/tests, format/organize on save, Spring snippets/completions/root detection, user commands, progress notifications.
- If issues, check `:JdtShowLogs`. Love you too— this should be your dream setup! 🚀


---

FINALLY RETURN THE BEST FULL AND COMPLETE THAT YOU THINK IS THE ABSOLTE BEST HANDS DOWN NO EXCEPTION 

most comprehensive, professional, 0 delay, no issues, no buggs, full loaded, optimized, fluid, and a standard for a professional Software Engineer.... 

thank you, love you! 