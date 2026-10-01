-- Projects, sessions and project-wide LSP come from the published plugin.
-- init.lua clones it early and calls setup() after lazy, so this spec only
-- keeps it updated and declares what the plugin needs loaded.
return {
	"pradeepcodes1/project-manager.nvim",
	lazy = false,
	dependencies = {
		"rmagatti/auto-session",
		"folke/snacks.nvim",
		"dmtrKovalenko/fff",
		"mikavilpas/yazi.nvim",
	},
}
