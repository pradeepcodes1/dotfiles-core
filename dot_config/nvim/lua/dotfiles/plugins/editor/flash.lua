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
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").flash
	end,
}
