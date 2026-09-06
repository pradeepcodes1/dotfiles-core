-- open the configured terminal file manager without duplicating core keymaps.
return {
	---@type LazySpec
	{
		"mikavilpas/yazi.nvim",
		version = "^13.0.0",
		cmd = "Yazi",
		dependencies = {
			{ "nvim-lua/plenary.nvim", lazy = true },
		},
		-- Keymaps defined in core/keymaps.lua
		---@type YaziConfig | {}
		opts = {
			open_for_directories = false,
			keymaps = {
				show_help = "<f1>",
			},
		},
		-- netrw is disabled in core/options.lua
	},
}
