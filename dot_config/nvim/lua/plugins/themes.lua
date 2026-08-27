-- lazy-load the curated palettes used by the cross-application theme switcher.
return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = true,
		opts = {
			integrations = { avante = false },
		},
	},
	{ "ellisonleao/gruvbox.nvim", lazy = true },
	{ "EdenEast/nightfox.nvim", lazy = true },
	{ "sainnhe/everforest", lazy = true },
	{ "rebelot/kanagawa.nvim", lazy = true },
	{
		"mslvx/obscure.nvim",
		lazy = true,
		opts = {
			transparent = os.getenv("_DOTFILES_THEME_TRANSPARENT") == "1",
		},
	},
}
