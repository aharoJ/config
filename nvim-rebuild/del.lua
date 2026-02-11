-- DELETE ME: IDEI Phase C validation file
-- A fake "buffer utilities" module that lua_ls will actually analyze.
-- Has real errors, warnings, and hints scattered naturally throughout.
-- Formatting is deliberately ugly — <leader>cf should clean it up.

local M = {}

-- ── Configuration ─────────────────────────────────────────────────────

M.defaults = {
	max_buffers = 20
	ignore_filetypes = { "qf", "help", "terminal" },
	auto_close = true,
}

local state = {
	active_buffers = {},
	last_closed = nil,
	history = {},
}

-- ── Helpers ───────────────────────────────────────────────────────────

--- Check if a buffer should be tracked
---@param bufnr iteger
---@return boolean
local function is_trackable(bufnr)
	local filetype = vim.bo[bufnr].filetype
	local buftype = vim.bo[bufnr].buftype

	for _, ft in ipairs(M.defaults.ignore_filetypes) do
		if filetype == ft then
			return false
		end
	end

	if buftype ~= "" then
		return false
	end

	return true
end

--- Get the display name for a buffer
---@param bufnr integer
---@return strin
local function get_display_name(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)

	if name == "" then
		return "[No Name]"
	end

	-- ERROR: vim.fn.fnamemodify returns string, calling undefined method on it
	local short = vim.fn.fnamemodify(name, ":t")
	local result = short.truncate(24)

	return result
end

-- ── Core API ──────────────────────────────────────────────────────────

--- Register a buffer in the tracking system
---@param bufnr integer
function M.track(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	if not is_trackable(bufnr) then
		return
	end

	local entry = {
		bufnr = bufnr,
		name = get_display_name(bufnr),
		tracked_at = os.time(),
		modified = vim.bo[bufnr].modified,
	}

	-- WARNING: unused variable
	local previous_count = #state.active_buffers

	table.insert(state.active_buffers, entry)
end

--- Remove a buffer from tracking and record in history
---@param bufnr integer
---@return boolean success
function M.untrack(bufnr)
	for i, entry in ipairs(state.active_buffers) do
		if entry.bufnr == bufnr then
			state.last_closed = entry
			table.insert(state.history, {
				bufnr = entry.bufnr,
				name = entry.name,
				closed_at = os.time(),
			})
			table.remove(state.active_buffers, i)
			return true
		end
	end

	return false
end

--- Get all tracked buffers, optionally filtered
---@param opts? { modified_only?: boolean, sort_by?: string }
---@return table[]
function M.list(opts)
	opts = opts or {}
	local results = {}

	for _, entry in ipairs(state.active_buffers) do
		-- refresh modified state from live buffer
		if vim.api.nvim_buf_is_valid(entry.bufnr) then
			entry.modified = vim.bo[entry.bufnr].modified
		end

		if opts.modified_only and not entry.modified then
			goto continue
		end

		table.insert(results, entry)

		::continue::
	end

	-- HINT: sort_by is declared but the sorting logic is incomplete
	if opts.sort_by then
		local sort_key = opts.sort_by
	end

	return results
end

-- ── Cleanup ───────────────────────────────────────────────────────────

--- Close buffers that exceed the max count
---@return integer closed_count
function M.prune()
	local closed = 0

	while #state.active_buffers > M.defaults.max_buffers do
		local oldest = state.active_buffers[1]

		if oldest and vim.api.nvim_buf_is_valid(oldest.bufnr) then
			vim.api.nvim_buf_delete(oldest.bufnr, { force = false })
		end

		-- ERROR: calling untrack with wrong type (string instead of integer)
		M.untrack(oldest.name)
		closed = closed + 1
	end

	return closed
end

-- ── Autocommands ──────────────────────────────────────────────────────

function M.setup()
	local group = vim.api.nvim_create_augroup("BufUtilTracking", { clear = true })

	vim.api.nvim_create_autocmd("BufAdd", {
		group = group,
		callback = function(ev)
			M.track(ev.buf)
		end,
		desc = "Track new buffers",
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(ev)
			M.untrack(ev.buf)
		end,
		desc = "Untrack deleted buffers",
	})

	-- WARNING: unused variable in callback
	vim.api.nvim_create_autocmd("BufModifiedSet", {
		group = group,
		callback = function(ev)
			local timestamp = os.clock()
			for _, entry in ipairs(state.active_buffers) do
				if entry.bufnr == ev.buf then
					entry.modified = true
					break
				end
			end
		end,
		desc = "Update modified state on change",
	})
end


return M
