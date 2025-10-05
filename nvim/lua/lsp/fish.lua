-- path: nvim/lua/lsp/fish.lua
local M = {}

function M.setup(ctx)
	-- Resolve binary fast (no shelling out every time)
	local function find_bin()
		local bin = vim.fn.exepath("fish-lsp")
		if bin ~= "" then
			return bin
		end
		for _, p in ipairs({ "/opt/homebrew/bin/fish-lsp", "/usr/local/bin/fish-lsp" }) do
			if vim.fn.executable(p) == 1 or vim.fn.filereadable(p) == 1 then
				return p
			end
		end
		return ""
	end

	local bin = find_bin()
	if bin == "" then
		vim.notify("[fish_lsp] fish-lsp not found on $PATH", vim.log.levels.WARN)
		return
	end

	-- Autostart / attach on Fish buffers.
	-- NOTE: vim.lsp.start() will reuse a matching client by (name, root_dir)
	-- so we don't need duplicate checks; it's already buttery-smooth.
	local aug = vim.api.nvim_create_augroup("fish_lsp_autostart", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = aug,
		pattern = "fish",
		callback = function(ev)
			local fname = vim.api.nvim_buf_get_name(ev.buf)
			if fname == "" then
				fname = (vim.uv or vim.loop).cwd()
			end
			local root = vim.fs.root(fname, { ".git", "config.fish" }) or vim.fs.dirname(fname)

			vim.lsp.start({
				name = "fish_lsp",
				cmd = { bin, "start" }, -- stdio is default; "start" is required
				root_dir = root,
				filetypes = { "fish" },
				single_file_support = true,
				on_attach = ctx.on_attach,
				capabilities = ctx.capabilities,
			}, { bufnr = ev.buf })
		end,
	})
end

return M
