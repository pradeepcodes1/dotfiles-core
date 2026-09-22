-- open the configured terminal file manager without duplicating core keymaps.
return {
	{
		"mikavilpas/yazi.nvim",
		version = "^13.0.0",
		cmd = "Yazi",
		dependencies = {
			{ "nvim-lua/plenary.nvim", lazy = true },
		},
		opts = {
			floating_window_scaling_factor = 0.6,
			yazi_floating_window_border = "double",
			highlight_hovered_buffers_in_same_directory = false,
			open_multiple_tabs = true,
		},
	},
}
