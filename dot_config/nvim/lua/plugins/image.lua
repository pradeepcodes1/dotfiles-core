-- use terminal image rendering only where Kitty's graphics protocol is available.
return {
	"3rd/image.nvim",
	enabled = not vim.g.neovide,
	ft = { "markdown" },
	opts = {
		integrations = {
			markdown = {
				clear_in_insert_mode = true,
				filetypes = { "markdown" },
			},
		},
		max_width = 100,
		max_height = 30,
		max_height_window_percentage = 40,
	},
}
