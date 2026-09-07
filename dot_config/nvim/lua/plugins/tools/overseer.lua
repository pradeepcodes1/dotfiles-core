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
	keys = {
		{ "<leader>or", "<Cmd>OverseerRun<CR>", desc = "Overseer: Run task" },
		{ "<leader>ot", "<Cmd>OverseerToggle<CR>", desc = "Overseer: Toggle tasks" },
		{ "<leader>os", "<Cmd>OverseerShell<CR>", desc = "Overseer: Run shell command" },
		{ "<leader>oa", "<Cmd>OverseerTaskAction<CR>", desc = "Overseer: Task action" },
	},
	---@module "overseer"
	---@type overseer.SetupOpts
	opts = {},
}
