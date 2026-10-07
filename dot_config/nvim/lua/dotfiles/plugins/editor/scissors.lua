-- add and edit snippets in a popup instead of hand-writing VSCode snippet JSON.
return {
	"chrisgrieser/nvim-scissors",
	cmd = { "ScissorsAddNewSnippet", "ScissorsEditSnippet" },
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").scissors
	end,
	opts = {
		-- Must match blink's snippets `search_paths` (plugins/lsp/blink.lua):
		-- scissors writes here and hot-reloads blink, which reads from there.
		-- The directory is a chezmoi symlink into the source checkout, so
		-- saves land in the repo directly.
		snippetDir = vim.fn.stdpath("config") .. "/snippets",
	},
}
