-- path: nvim/lua/core/tools-binaries.lua
-- path: nvim/lua/core/tools-binaries.lua
local M = {}

-- ── Catalog ───────────────────────────────────────────────────────────────────
local TOOLS = {
	-- Runtimes
	{ name = "Node.js", cmd = "node", kind = "runtime" },
	{ name = "Python", cmd = "python3", kind = "runtime" },
	{ name = "Java JDK", cmd = "java", kind = "runtime" },

	-- LSP servers
	{ name = "LuaLS", cmd = "lua-language-server", kind = "lsp" },
	{ name = "Pyright", cmd = "pyright-langserver", kind = "lsp" },
	{ name = "Ruff (server)", cmd = "ruff", kind = "lsp" }, -- `ruff server`
	{ name = "BashLS", cmd = "bash-language-server", kind = "lsp" },
	{ name = "Fish LSP", cmd = "fish-lsp", kind = "lsp" },
	{ name = "Taplo (TOML)", cmd = "taplo", kind = "lsp" }, -- `taplo lsp stdio`
	{ name = "YAML LS", cmd = "yaml-language-server", kind = "lsp" },
	{ name = "VTSLS", cmd = "vtsls", kind = "lsp" },
	{ name = "CSS LS", cmd = "vscode-css-language-server", kind = "lsp" },
	{ name = "HTML LS", cmd = "vscode-html-language-server", kind = "lsp" },
	{ name = "Tailwind CSS LS", cmd = "tailwindcss-language-server", kind = "lsp" },
	{ name = "ESLint LS", cmd = "vscode-eslint-language-server", kind = "lsp" },

	-- Formatters
	{ name = "StyLua", cmd = "stylua", kind = "formatter" },
	{ name = "Prettier", cmd = "prettier", kind = "formatter" },
	{ name = "eslint_d (fmt)", cmd = "eslint_d", kind = "formatter" },
	{ name = "yamlfmt", cmd = "yamlfmt", kind = "formatter" },
	{ name = "shfmt", cmd = "shfmt", kind = "formatter" },

	-- Linters
	{ name = "ShellCheck", cmd = "shellcheck", kind = "linter" },
	{ name = "yamllint", cmd = "yamllint", kind = "linter" },
	{ name = "Checkstyle", cmd = "checkstyle", kind = "linter" },
}

function M.register_extra(list)
	for _, t in ipairs(list or {}) do
		table.insert(TOOLS, t)
	end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function exepath(cmd)
	local p = vim.fn.exepath(cmd)
	if p ~= "" then
		return p
	end
	local HOME = vim.loop.os_homedir()
	local candidates = {
		"/opt/homebrew/bin/" .. cmd,
		"/usr/local/bin/" .. cmd,
		HOME .. "/.local/bin/" .. cmd, -- pipx / user bin
		HOME .. "/.npm-global/bin/" .. cmd,
		HOME .. "/.yarn/bin/" .. cmd,
	}
	for _, g in ipairs(candidates) do
		if vim.fn.executable(g) == 1 or vim.fn.filereadable(g) == 1 then
			return g
		end
	end
	return ""
end

local VERSION_FLAGS = {
	["ruff"] = { "--version" },
	["pyright-langserver"] = { "--version" },
	["lua-language-server"] = { "-v", "--version" },
	["bash-language-server"] = { "--version" },
	["fish-lsp"] = { "--version" },
	["taplo"] = { "--version", "-V" },
	["yaml-language-server"] = { "--version" },
	["vtsls"] = { "--version" },
	["vscode-css-language-server"] = { "--version" },
	["vscode-html-language-server"] = { "--version" },
	["tailwindcss-language-server"] = { "--version" },
	["vscode-eslint-language-server"] = { "--version" },
	["stylua"] = { "--version" },
	["prettier"] = { "--version" },
	["eslint_d"] = { "--version" },
	["yamlfmt"] = { "--version" },
	["shfmt"] = { "--version" },
	["shellcheck"] = { "--version" },
	["yamllint"] = { "--version" },
	["node"] = { "--version" },
	["python3"] = { "--version" },
	["java"] = { "-version" }, -- stderr
}

local function truncate(s, max)
	s = s or ""
	if #s <= max then
		return s
	end
	return s:sub(1, math.max(0, max - 1)) .. "…"
end

local function short_version_text(out)
	-- normalize whitespace
	out = (out or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if out == "" then
		return ""
	end
	-- try semver-ish with optional leading v
	local v = out:match("[vV]?%d+%.%d+%.%d+[%w%.-]*")
		or out:match("[vV]?%d+%.%d+[%w%.-]*")
		or out:match("version[%s:]*([%d%._%-]+)")
	if v then
		return v
	end
	-- fallback: first token
	return (out:match("^%S+") or out)
end

local function read_version(abs_cmd)
	local base = vim.fn.fnamemodify(abs_cmd, ":t")
	local flags = VERSION_FLAGS[base] or { "--version", "-v", "version" }
	for _, flag in ipairs(flags) do
		local res = vim.system({ abs_cmd, flag }, { text = true }):wait()
		local out = (res.stdout or "") .. (res.stderr or "")
		local s = short_version_text(out)
		if s ~= "" then
			return s
		end
	end
	return ""
end

local function icon(ok)
	return ok and "✓" or "✗"
end

-- ── Data build ────────────────────────────────────────────────────────────────
local function build_rows()
	local lines, any_missing = {}, false
	local ok_count = 0
	table.insert(
		lines,
		"── Tools Health ─────────────────────────────────────────"
	)
	table.insert(lines, string.format("%-2s %-24s %-10s %-16s %s", "", "Name", "Kind", "Version", "Path"))
	table.insert(
		lines,
		"──────────────────────────────────────────────────────────────"
	)

	for _, t in ipairs(TOOLS) do
		local path = exepath(t.cmd)
		local ok = path ~= ""
		if ok then
			ok_count = ok_count + 1
		else
			any_missing = true
		end
		local ver = ok and read_version(path) or ""
		table.insert(
			lines,
			string.format(
				"%s  %-24s %-10s %-16s %s",
				icon(ok),
				t.name,
				t.kind,
				truncate(ver, 16),
				(ok and path or "NOT FOUND")
			)
		)
	end

	table.insert(
		lines,
		"──────────────────────────────────────────────────────────────"
	)
	table.insert(lines, string.format("Status: %d/%d OK", ok_count, #TOOLS))
	return lines, any_missing
end

-- ── UI commands ───────────────────────────────────────────────────────────────
function M.report()
	local rows, any_missing = build_rows()
	local level = any_missing and vim.log.levels.WARN or vim.log.levels.INFO
	vim.notify(table.concat(rows, "\n"), level, { title = "Tools Health" })
end

function M.report_open()
	-- single-var assignment = only first return (the lines table)
	local lines = build_rows()
	if type(lines) ~= "table" then
		lines = { tostring(lines) }
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"

	-- centered float
	local ui = vim.api.nvim_list_uis()[1] or { width = 120, height = 40 }
	local width = math.min(math.max(70, math.floor(ui.width * 0.7)), ui.width - 2)
	local height = math.min(math.max(12, #lines + 2), math.floor(ui.height * 0.8))
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = "rounded",
	})

	vim.wo[win].wrap = false
	vim.keymap.set("n", "q", function()
		pcall(vim.api.nvim_win_close, win, true)
	end, { buffer = buf, silent = true, desc = "Close tools health window" })
end

function M.install_hints()
	local hints = {
		"── Install Hints (macOS) ─────────────────────",
		"brew install fish-lsp taplo yamlfmt shellcheck shfmt stylua",
		"npm  -g install yaml-language-server bash-language-server vtsls tailwindcss-language-server prettier eslint_d",
		"npm  -g install vscode-langservers-extracted   # html/css/json servers",
		"pipx install yamllint ruff pyright             # ensure ~/.local/bin is on PATH",
		"Java: brew install temurin && export JAVA_HOME=$(/usr/libexec/java_home)",
	}
	vim.notify(table.concat(hints, "\n"), vim.log.levels.INFO, { title = "Tools Install" })
end

vim.api.nvim_create_user_command("ToolsHealth", M.report, {})
vim.api.nvim_create_user_command("ToolsHealthOpen", M.report_open, {})
vim.api.nvim_create_user_command("ToolsInstallHints", M.install_hints, {})

return M
