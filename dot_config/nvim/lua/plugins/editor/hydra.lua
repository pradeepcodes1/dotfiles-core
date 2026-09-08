return {
	"nvimtools/hydra.nvim",
	config = function()
		local Hydra = require("hydra")

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
			-- Modal resize controls are kept with every other binding definition.
			heads = require("core.keymaps").resize_hydra_heads(),
		})
	end,
}
