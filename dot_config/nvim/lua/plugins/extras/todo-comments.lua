-- highlight maintenance notes without adding decorative icons to source text.
return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		keywords = {
			FIX = { icon = " " },
			TODO = { icon = " " },
			HACK = { icon = " " },
			WARN = { icon = " " },
			PERF = { icon = " " },
			NOTE = { icon = " " },
		},
	},
}
