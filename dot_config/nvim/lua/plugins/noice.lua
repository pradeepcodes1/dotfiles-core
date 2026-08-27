-- suppress routine LSP chatter so notifications stay reserved for actionable messages.
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
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
			{
				filter = {
					warning = true,
				},
				opts = { skip = true },
			},
		},
	},
}
