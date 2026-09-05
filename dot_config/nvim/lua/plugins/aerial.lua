local close_symbols = {
	callback = function()
		vim.cmd("AerialClose")
	end,
	desc = "Close Symbols sidebar",
}

return {
	"stevearc/aerial.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "AerialToggle", "AerialOpen", "AerialClose" },
	opts = {
		backends = { "lsp", "treesitter", "markdown", "man" },
		layout = {
			default_direction = "right",
			-- Symbols need less horizontal room than the file explorer.
			width = 30,
			min_width = 30,
			max_width = 30,
			resize_to_content = false,
			win_opts = {
				winbar = " Symbols",
			},
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
			["q"] = close_symbols,
			["<C-q>"] = close_symbols,
			["Q"] = close_symbols,
			["<leader>x"] = close_symbols,
			["<C-w>c"] = close_symbols,
			["<C-w>q"] = close_symbols,
			["o"] = "actions.tree_toggle",
		},
	},
}
