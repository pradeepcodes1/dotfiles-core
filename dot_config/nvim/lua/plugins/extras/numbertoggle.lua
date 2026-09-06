-- keep relative numbers where they are useful - normal mode in the focused
-- window - and fall back to absolute numbers everywhere else, so an inactive
-- split still shows the real line a message or reviewer refers to.
return {
	"sitiom/nvim-numbertoggle",

	-- The plugin registers its autocmds from plugin/, so it only needs to be
	-- loaded once the UI is up; options.lua already opens on relativenumber.
	event = "VeryLazy",
}
