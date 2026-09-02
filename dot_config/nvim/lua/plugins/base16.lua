-- supply the highlight set that colors/dotfiles-gogh.lua maps Gogh palettes onto.
return {
	"echasnovski/mini.base16",
	-- The colorscheme is applied at the end of init.lua, so this has to be on
	-- the runtimepath before lazy finishes rather than on any later event.
	lazy = false,
	priority = 1000,
	-- colors/dotfiles-gogh.lua calls setup() with the palette it builds; there
	-- is nothing to configure here.
	config = function() end,
}
