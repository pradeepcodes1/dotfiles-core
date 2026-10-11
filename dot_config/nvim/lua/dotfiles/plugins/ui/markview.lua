-- render Markdown in the buffer itself: headings, tables, code blocks and lists
-- get their decorated form while the cursor is elsewhere, plain text on the
-- line being edited.
return {
	"OXY2DEV/markview.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	ft = { "markdown" },
	opts = {},
}
