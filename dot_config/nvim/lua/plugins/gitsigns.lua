-- surface line provenance inline so routine blame checks need no separate view.
return {
	{
		"lewis6991/gitsigns.nvim",
		event = "BufReadPre",

		opts = {
			current_line_blame = true,
			current_line_blame_opts = { delay = 0 },
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				local map_opts = { buffer = bufnr, silent = true }

				vim.keymap.set("n", "]h", function()
					gitsigns.nav_hunk("next")
				end, vim.tbl_extend("force", map_opts, { desc = "Next Git hunk" }))
				vim.keymap.set("n", "[h", function()
					gitsigns.nav_hunk("prev")
				end, vim.tbl_extend("force", map_opts, { desc = "Previous Git hunk" }))
				vim.keymap.set(
					"n",
					"<leader>gb",
					gitsigns.blame,
					vim.tbl_extend("force", map_opts, { desc = "Blame current file" })
				)
			end,
		},
	},
}
