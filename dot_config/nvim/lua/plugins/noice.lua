-- suppress routine LSP chatter so notifications stay reserved for actionable messages.
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	opts = {
		routes = {
			{
				filter = {
					event = "notify",
					find = "No results from textDocument/documentSymbol",
				},
				opts = { skip = true },
			},
			{
				filter = {
					event = "lsp",
					kind = "message",
				},
				opts = { skip = true },
			},
			-- Snacks pickers close themselves and warn when a finder comes back
			-- empty ("No results found for `todo_comments`" on <leader>ft, and
			-- the same for files/grep). That is the only feedback the picker
			-- gives, so it has to outrank the blanket warning skip below --
			-- routes are matched in order and the first match stops the search.
			{
				filter = {
					event = "notify",
					find = "^No results",
				},
				view = "notify",
			},
			{
				filter = {
					warning = true,
				},
				opts = { skip = true },
			},
		},
	},
}
