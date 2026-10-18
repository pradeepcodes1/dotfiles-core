-- VSCode-style sticky scroll: pin the enclosing class/function headers at the
-- top of the window so deep code still shows where it lives.
return {
	"nvim-treesitter/nvim-treesitter-context",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		-- Three pinned lines, like VSCode; deeper nesting drops the outermost first.
		max_lines = 3,
		trim_scope = "outer",
		-- Follow the top visible line rather than the cursor, as VSCode does.
		mode = "topline",
		-- A wrapped multi-line signature pins as just its first line.
		multiline_threshold = 1,
		-- Tiny windows (splits, previews) have no room to spare for headers.
		min_window_height = 15,
		-- Only real file buffers; markview already structures Markdown.
		on_attach = function(buf)
			return vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "markdown"
		end,
	},
}
