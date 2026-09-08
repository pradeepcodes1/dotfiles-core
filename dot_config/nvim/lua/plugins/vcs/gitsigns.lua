-- surface line provenance inline so routine blame checks need no separate view.
return {
	{
		"lewis6991/gitsigns.nvim",
		event = "BufReadPre",
		dependencies = { "nvimtools/hydra.nvim" },

		opts = {
			-- Encode staging state in the glyph so it stays readable without relying on subtle colors.
			signs = {
				add = { text = "U+" },
				change = { text = "U~" },
				delete = { text = "U-" },
				topdelete = { text = "U^" },
				changedelete = { text = "U~" },
				untracked = { text = "??" },
			},
			signs_staged_enable = true,
			signs_staged = {
				add = { text = "S+" },
				change = { text = "S~" },
				delete = { text = "S-" },
				topdelete = { text = "S^" },
				changedelete = { text = "S~" },
			},
			current_line_blame = true,
			current_line_blame_opts = { delay = 0 },
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				local map_opts = { buffer = bufnr, silent = true }

				-- Keep hunk review active so navigation and actions need only one leader prefix.
				local hunk_hydra = require("hydra")({
					name = "Git hunks",
					mode = "n",
					config = {
						buffer = bufnr,
						color = "pink",
						invoke_on_body = true,
						hint = { float_opts = { border = "rounded" } },
					},
					hint = [[
 Git hunks
 _j_: next   _k_: previous   _p_: preview   _b_: blame
 _s_: stage  _u_: undo stage _r_: reset     _q_/_<Esc>_: exit
]],
					heads = {
						{
							"j",
							function()
								gitsigns.nav_hunk("next")
							end,
							{ desc = "next" },
						},
						{
							"k",
							function()
								gitsigns.nav_hunk("prev")
							end,
							{ desc = "previous" },
						},
						{ "p", gitsigns.preview_hunk, { desc = "preview" } },
						{
							"b",
							function()
								gitsigns.blame_line({ full = true })
							end,
							{ desc = "blame" },
						},
						{ "s", gitsigns.stage_hunk, { desc = "stage/unstage" } },
						{ "u", gitsigns.undo_stage_hunk, { desc = "undo stage" } },
						{ "r", gitsigns.reset_hunk, { desc = "reset" } },
						{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
						{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
					},
				})
				-- Working buffers can appear in both normal and CodeDiff tabs; dispatch by the active tab.
				vim.keymap.set("n", "<leader>h", function()
					if vim.t.codediff_view then
						require("ui.codediff_hydra").activate()
					else
						hunk_hydra:activate()
					end
					-- Enter immediately; subsequent action keys belong to the active Hydra.
				end, vim.tbl_extend("force", map_opts, { desc = "Git / CodeDiff hunk navigation", nowait = true }))

				for _, action in ipairs({
					{ "hs", "stage_hunk", "Stage/unstage Git hunk" },
					{ "hr", "reset_hunk", "Discard working-tree hunk changes" },
				}) do
					-- Visual mappings retain range-based hunk actions outside the normal-mode Hydra.
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
