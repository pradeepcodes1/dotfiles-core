-- open the configured terminal file manager without duplicating core keymaps.
return {
	{
		"mikavilpas/yazi.nvim",
		-- v14 only drops Yazi 26.1.4 support; Homebrew ships 26.9.1.
		version = "^14.0.0",
		cmd = "Yazi",
		dependencies = {
			{ "nvim-lua/plenary.nvim", lazy = true },
		},
		opts = {
			floating_window_scaling_factor = 0.6,
			-- No border override: yazi.nvim defaults to 'winborder', keeping it
			-- consistent with the other floats.
			highlight_hovered_buffers_in_same_directory = false,
			open_multiple_tabs = true,
		},
	},
}
