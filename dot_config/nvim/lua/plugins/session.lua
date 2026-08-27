-- restore project sessions automatically without preserving transient utility buffers.
return {
	"rmagatti/auto-session",
	lazy = false,
	init = function()
		vim.opt.sessionoptions:append("localoptions")
	end,
	keys = {
		-- Will use Telescope if installed or a vim.ui.select picker otherwise
		{ "<leader>sr", "<cmd>AutoSession search<CR>", desc = "Session search" },
		{ "<leader>ss", "<cmd>AutoSession save<CR>", desc = "Save session" },
		{ "<leader>sa", "<cmd>AutoSession autosave toggle<CR>", desc = "Toggle autosave" },
	},

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		-- Disable auto-restore to prevent unexpected session reloading
		-- when opening files outside the current folder (issue #129)
		auto_restore = false,
		-- Use git branch name in session file name
		git_use_branch_name = true,
		-- Suppress session creation/restoration in these directories
		suppressed_dirs = {
			"~/",
			"~/Downloads",
			"~/Desktop",
			"~/Documents",
			"/tmp",
			"/",
		},
		-- Handle cwd changes by updating session
		cwd_change_handling = true,
		-- Don't auto-save when these file types are the only ones open
		bypass_save_filetypes = { "alpha", "dashboard", "lazy" },
	},
}
