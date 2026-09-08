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
	-- Lazy.nvim reads the shared group without duplicating binding ownership here.
	keys = require("core.keymaps").plugin.overseer,
	---@module "overseer"
	---@type overseer.SetupOpts
	opts = {},
}
