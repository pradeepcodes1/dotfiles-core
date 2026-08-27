-- provide a tabbed floating terminal without changing the shared Edgy layouts.
local next_terminal = 1

local function new_terminal()
	next_terminal = next_terminal + 1
	require("betterTerm").open(next_terminal)
end

return {
	{
		"CRAG666/betterTerm.nvim",
		enabled = not vim.g.nvim_preview,
		lazy = true,
		keys = vim.g.neovide and {
			{
				"<D-j>",
				function()
					require("betterTerm").toggle_termwindow()
				end,
				mode = { "n", "i", "t" },
				silent = true,
				desc = "Toggle tabbed terminal",
			},
		} or nil,
		opts = {
			display = "float",
			float_config = {
				relative = "editor",
				width = 0.9,
				height = 0.9,
				border = "rounded",
			},
			startInserted = true,
			show_tabs = true,
			new_tab_mapping = "<Plug>(BetterTermNew)",
			jump_tab_mapping = "<D-$tab>",
			index_base = 1,
		},
		config = function(_, opts)
			local betterterm = require("betterTerm")
			betterterm.setup(opts)

			-- Avoid the plugin's overlapping second float when adding a tab.
			_G.BetterTerm.new_term_from_winbar = new_terminal
			vim.keymap.set("t", "<D-t>", new_terminal, { silent = true, desc = "New terminal tab" })
			vim.keymap.set({ "n", "t" }, "<D-S-[>", function()
				betterterm.cycle(-1)
			end, { silent = true, desc = "Previous terminal tab" })
			vim.keymap.set({ "n", "t" }, "<D-S-]>", function()
				betterterm.cycle(1)
			end, { silent = true, desc = "Next terminal tab" })
		end,
	},
}
