return {
	"Aasim-A/scrollEOF.nvim",
	event = { "CursorMoved", "WinScrolled" },
	opts = {
		-- Optional: disable in terminal buffers
		disabled_filetypes = { "terminal" },
		-- Optional: keep working in floating windows
		floating = true,
		-- Optional: keep it off in insert mode (default)
		insert_mode = false,
	},
}
