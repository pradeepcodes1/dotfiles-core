return {
	"nvimtools/hydra.nvim",
	config = function()
		local Hydra = require("hydra")

		local function resize(command)
			return function()
				-- Counts still multiply the normal ten-column/line resize step.
				vim.cmd(command .. (10 * vim.v.count1))
			end
		end

		Hydra({
			name = "Resize splits",
			mode = "n",
			body = "<leader>w",
			config = {
				color = "pink",
				invoke_on_body = true,
				-- Keep the hint on Hydra's current floating-window configuration API.
				hint = { float_opts = { border = "rounded" } },
			},
			hint = [[
 Split resize
 _h_: narrower   _l_: wider
 _j_: shorter    _k_: taller
 _=_: equalize           _q_/_<Esc>_: exit
]],
			heads = {
				{ "h", resize("vertical resize -"), { desc = "narrower" } },
				{ "<Left>", resize("vertical resize -"), { desc = "narrower" } },
				{ "l", resize("vertical resize +"), { desc = "wider" } },
				{ "<Right>", resize("vertical resize +"), { desc = "wider" } },
				{ "j", resize("resize -"), { desc = "shorter" } },
				{ "<Down>", resize("resize -"), { desc = "shorter" } },
				{ "k", resize("resize +"), { desc = "taller" } },
				{ "<Up>", resize("resize +"), { desc = "taller" } },
				{ "=", "<C-w>=", { desc = "equalize" } },
				{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
				{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
			},
		})
	end,
}
