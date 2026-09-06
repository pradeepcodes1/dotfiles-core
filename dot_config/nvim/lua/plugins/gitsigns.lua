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
				vim.keymap.set(
					"n",
					"<leader>hp",
					gitsigns.preview_hunk,
					vim.tbl_extend("force", map_opts, { desc = "Preview Git hunk" })
				)
				for _, action in ipairs({
					{ "hs", "stage_hunk", "Stage/unstage Git hunk" },
					{ "hr", "reset_hunk", "Discard working-tree hunk changes" },
				}) do
					vim.keymap.set("n", "<leader>" .. action[1], function()
						gitsigns[action[2]]()
					end, vim.tbl_extend("force", map_opts, { desc = action[3] }))
					vim.keymap.set("x", "<leader>" .. action[1], function()
						local first, last = vim.fn.line("v"), vim.fn.line(".")
						gitsigns[action[2]]({ math.min(first, last), math.max(first, last) })
					end, vim.tbl_extend("force", map_opts, { desc = action[3] .. " (selection)" }))
				end

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
