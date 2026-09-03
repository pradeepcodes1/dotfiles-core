-- label a jump target so crossing a screen is two keys instead of a counted motion.
return {
	"folke/flash.nvim",
	-- Not `keys`-only, which is what folke's own spec uses: `modes.char` hooks
	-- f/F/t/T/;/, at setup time, and none of those are in the `keys` list below,
	-- so a lazy load gated on them would leave the enhanced ftFT motions dead
	-- until the first `s`.
	event = "VeryLazy",
	---@module "flash"
	---@type Flash.Config
	opts = {},
	keys = {
		-- `s` and `S` shadow the builtin substitute operators. `cl` and `cc` are
		-- the unshadowed spellings; this is flash's standard trade and the one
		-- thing to revert first if the muscle memory fights back.
		{
			"s",
			mode = { "n", "x", "o" },
			function()
				require("flash").jump()
			end,
			desc = "Flash",
		},
		{
			"S",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter()
			end,
			desc = "Flash Treesitter",
		},
		-- Operator-pending only, so `dr`/`yr` act on a labelled range elsewhere
		-- in the window without moving the cursor there. Normal-mode `r`
		-- (replace char) is untouched.
		{
			"r",
			mode = "o",
			function()
				require("flash").remote()
			end,
			desc = "Remote Flash",
		},
		{
			"R",
			mode = { "o", "x" },
			function()
				require("flash").treesitter_search()
			end,
			desc = "Treesitter Search",
		},
		-- Toggles labels during an active search. `modes.search.enabled` is
		-- false by default, so this is the only way in -- and it only ever
		-- reaches `/`, since core/keymaps.lua rebinds normal-mode `?` to the
		-- diagnostic float. Unrelated to the picker's own `<C-s>` split action,
		-- which is a different mode in a different window.
		{
			"<c-s>",
			mode = { "c" },
			function()
				require("flash").toggle()
			end,
			desc = "Toggle Flash Search",
		},
	},
}
