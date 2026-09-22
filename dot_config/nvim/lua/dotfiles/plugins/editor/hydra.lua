-- Hydra consumes this table itself, but its modal keys are still bindings and
-- belong beside the Hydra they drive.
local function resize_heads()
	local function resize(command)
		return function()
			vim.cmd(command .. (10 * vim.v.count1))
		end
	end
	-- Arrow and home-row spellings perform the same modal resize operations.
	return {
		-- The hint stays out of the way until it is explicitly requested.
		{
			"?",
			function()
				if _G.Hydra then
					_G.Hydra.hint:show()
				end
			end,
			{ desc = "show help" },
		},
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
	}
end

return {
	"nvimtools/hydra.nvim",
	config = function()
		local Hydra = require("hydra")

		Hydra({
			name = "Resize splits",
			body = "<leader>w",
			config = {
				color = "pink",
				invoke_on_body = true,
				-- Keep the hint on Hydra's current floating-window configuration API.
				-- Keep resize controls modal without showing help until it is needed.
				hint = { float_opts = { border = "rounded" }, hide_on_load = true },
			},
			hint = [[
 Split resize
 _h_: narrower   _l_: wider
 _j_: shorter    _k_: taller
 _=_: equalize           _q_/_<Esc>_: exit
]],
			heads = resize_heads(),
		})
	end,
}
