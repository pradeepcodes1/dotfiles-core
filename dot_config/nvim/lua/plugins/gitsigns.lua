-- surface line provenance inline so routine blame checks need no separate view.
return {
	{
		"lewis6991/gitsigns.nvim",
		event = "BufReadPre",

		opts = {
			current_line_blame = true,
			current_line_blame_opts = { delay = 0 },
		},
	},
}
