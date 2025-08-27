-- Force uppercase .MD files to be treated as markdown
vim.filetype.add({
	extension = {
		MD = "markdown", -- uppercase .MD
		RMD = "markdown", -- uppercase R Markdown
		rmd = "markdown", -- lowercase R Markdown
		mdx = "markdown", -- MDX (Markdown + JSX)
	},
})
