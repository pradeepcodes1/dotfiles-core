-- rewrite a pattern across the project from one editable results buffer,
-- instead of grep, then quickfix, then a hand-written :cdo.
return {
	"MagicDuck/grug-far.nvim",
	enabled = not vim.g.nvim_preview,
	cmd = "GrugFar",
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").grug_far
	end,
	opts = {
		-- Unlisted and wiped once hidden, so a finished replace never lingers in
		-- the buffer list or gets written into an auto-session.
		transient = true,
	},
}
