-- path: nvim/lua/lsp/marksman.lua
-- path: nvim/lua/lsp/marksman.lua
local M = {}

function M.setup(ctx)
	-- Fast, resilient bin resolve
	local function find_bin()
		local bin = vim.fn.exepath("marksman")
		if bin ~= "" then
			return bin
		end
		for _, p in ipairs({ "/opt/homebrew/bin/marksman", "/usr/local/bin/marksman" }) do
			if vim.fn.executable(p) == 1 or vim.fn.filereadable(p) == 1 then
				return p
			end
		end
		return ""
	end

	local bin = find_bin()
	if bin == "" then
		vim.notify("[marksman] binary not found on $PATH", vim.log.levels.WARN)
		return
	end

	-- Autostart/attach on Markdown buffers (like your Fish setup)
	-- vim.lsp.start() dedupes by (name, root_dir) so we don’t need manual guards.
	local aug = vim.api.nvim_create_augroup("marksman_autostart", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = aug,
		pattern = { "markdown", "markdown.mdx" }, -- cover normal MD + MDX ftdetect
		callback = function(ev)
			local fname = vim.api.nvim_buf_get_name(ev.buf)
			if fname == "" then
				fname = (vim.uv or vim.loop).cwd()
			end

			-- Prefer VCS root; fall back to file dir
			local root = vim.fs.root(fname, { ".git" }) or vim.fs.dirname(fname)

			vim.lsp.start({
				name = "marksman",
				cmd = { bin, "server" }, -- official entrypoint
				root_dir = root,
				filetypes = { "markdown", "markdown.mdx" },
				single_file_support = true,
				on_attach = ctx.on_attach,
				capabilities = ctx.capabilities,
				settings = {
					["marksman"] = {
						sync_on_open = true,
						path = { "auto" },
						diagnostics = { enabled = true },
						front_matter = { enabled = true },
					},
				},
			}, { bufnr = ev.buf })
		end,
	})
end

return M
