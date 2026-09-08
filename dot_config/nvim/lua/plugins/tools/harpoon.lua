-- Keep a small, persistent working set without competing with buffer or split navigation.
return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	enabled = not vim.g.nvim_preview,
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon:setup({
			settings = {
				sync_on_ui_close = true,
			},
		})
		harpoon:extend(require("harpoon.extensions").builtins.highlight_current_file())
	end,
	-- Generate numbered marks centrally while retaining lazy plugin activation.
	keys = require("core.keymaps").harpoon,
}
