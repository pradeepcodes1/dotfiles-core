-- restore project sessions automatically without preserving transient utility buffers.
return {
	"rmagatti/auto-session",
	lazy = false,
	init = function()
		vim.opt.sessionoptions:append("localoptions")
	end,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		-- Sessions are restored deliberately through <leader>p or the confirmed
		-- single-file project prompt, never unconditionally on startup.
		-- This was originally set to work around project.nvim silently chdir'ing
		-- on BufEnter/LspAttach (issue #129); that plugin is gone and cwd is now
		-- stable, so flipping this to true is safe if startup restore is wanted.
		auto_restore = false,
		-- File arguments normally disable AutoSession saving. The project prompt
		-- opts an instance back in only after its cwd has moved to the project.
		args_allow_files_auto_save = function()
			return require("core.project").is_open()
		end,
		pre_cwd_changed_cmds = {
			function()
				require("core.project").set_open(false)
			end,
		},
		post_restore_cmds = {
			function()
				local project = require("core.project")
				project.set_open(true, project.session_root())
			end,
		},
		no_restore_cmds = {
			function()
				local project = require("core.project")
				-- A dashboard picker can restore a project while AutoSession's
				-- delayed startup check is still pending. Its subsequent no-restore
				-- hook must not demote that successfully restored session to
				-- file-only mode.
				local root = project.session_root()
				project.set_open(root ~= nil, root)
			end,
		},
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
