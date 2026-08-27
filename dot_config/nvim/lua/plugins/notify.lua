-- keep transient notices compact so they do not cover the editing surface.
return {
	{
		"rcarriga/nvim-notify",
		lazy = true,
		opts = {
			background_colour = "#000000",
			stages = "static",
			timeout = 1500,
			minimum_width = 10,
			render = "minimal",
			top_down = true,
			icons = {
				ERROR = " ",
				WARN = " ",
				INFO = " ",
				DEBUG = " ",
				TRACE = "✎ ",
			},
		},
	},
}
