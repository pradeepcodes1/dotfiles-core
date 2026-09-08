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
					-- Hydra receives its modal controls from the same central binding source.
					heads = require("core.keymaps").gitsigns_hydra_heads(gitsigns),
				})
				-- Gitsigns supplies runtime objects; the central module owns their bindings.
				require("core.keymaps").gitsigns_on_attach(bufnr, gitsigns, hunk_hydra)
			end,
		},
	},
}
