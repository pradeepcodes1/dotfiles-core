-- make Symbols share one stable sidebar with Neo-tree under Edgy.
local close_sidebar = {
	callback = function()
		require("edgy").close("left")
	end,
	desc = "Close Explorer + Symbols sidebar",
}

return {
	"stevearc/aerial.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "AerialToggle", "AerialOpen" },
	opts = {
		backends = { "lsp", "treesitter", "markdown", "man" },
		layout = {
			default_direction = "left",
			-- Edgy owns the shared Explorer/Symbols column geometry. Letting
			-- Aerial size to each buffer's symbols makes the whole column reflow.
			width = 40,
			min_width = 40,
			max_width = 40,
			resize_to_content = false,
		},
		attach_mode = "global",
		filter_kind = false,
		show_guides = true,
		guides = {
			mid_item = "├ ",
			last_item = "└ ",
			nested_top = "│ ",
			whitespace = "  ",
		},
		highlight_on_hover = true,
		autojump = true,
		close_on_select = false,
		keymaps = {
			["<CR>"] = "actions.jump",
			["<C-v>"] = "actions.jump_vsplit",
			["<C-s>"] = "actions.jump_split",
			["q"] = close_sidebar,
			["<C-q>"] = close_sidebar,
			["Q"] = close_sidebar,
			["<leader>x"] = close_sidebar,
			["<C-w>c"] = close_sidebar,
			["<C-w>q"] = close_sidebar,
			["o"] = "actions.tree_toggle",
		},
	},
}
