-- Load Overseer only when its task commands are used so ordinary editing stays lightweight.
return {
	"stevearc/overseer.nvim",
	enabled = not vim.g.nvim_preview,
	cmd = {
		"OverseerClose",
		"OverseerOpen",
		"OverseerRun",
		"OverseerShell",
		"OverseerTaskAction",
		"OverseerToggle",
	},
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").overseer
	end,
	---@module "overseer"
	---@type overseer.SetupOpts
	opts = {},
}
