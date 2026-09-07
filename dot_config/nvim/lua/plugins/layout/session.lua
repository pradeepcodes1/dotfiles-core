-- restore project sessions automatically without preserving transient utility buffers.
return {
	"rmagatti/auto-session",
	lazy = false,
	init = function()
		vim.opt.sessionoptions:append("localoptions")
		-- A session can only restart a terminal command, not restore its shell
		-- process or scrollback. Leave terminals out and open a fresh one on
		-- demand with <leader>pt instead of presenting a misleading empty shell.
		vim.opt.sessionoptions:remove("terminal")
		-- Keep the project picker clean without a manual maintenance binding.
		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				require("project.actions.pruner").prune_stale_sessions({ notify = false })
			end,
			desc = "Prune stale project sessions",
		})
	end,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		-- Neovim sessions cannot serialize transient panel state, so keep it in
		-- AutoSession's companion data file instead of the native layout snapshot.
		save_extra_data = function()
			return require("sessions.state").capture()
		end,
		restore_extra_data = function(_, extra_data)
			require("sessions.state").stage(extra_data)
		end,
		-- Sessions are restored deliberately through <leader>pp or the confirmed
		-- single-file project prompt, never unconditionally on startup.
		-- This was originally set to work around project.nvim silently chdir'ing
		-- on BufEnter/LspAttach (issue #129); that plugin is gone and cwd is now
		-- stable, so flipping this to true is safe if startup restore is wanted.
		auto_restore = false,
		-- File arguments normally disable AutoSession saving. The project prompt
		-- opts an instance back in only after its cwd has moved to the project.
		args_allow_files_auto_save = function()
			return require("project.state").is_open()
		end,
		pre_save_cmds = {
			function()
				-- The debug tab is reconstructed from custom data and must not also enter the native session.
				require("ui.dapui").suspend_for_save()
			end,
		},
		post_save_cmds = {
			function()
				-- Manual saves preserve the live UI after the native session snapshot is complete.
				require("ui.dapui").resume_after_save()
			end,
		},
		pre_cwd_changed_cmds = {
			function()
				require("project.state").set_open(false)
			end,
		},
		post_restore_cmds = {
			function()
				local project_state = require("project.state")
				local project_paths = require("project.paths")
				project_state.set_open(true, project_paths.session_root())
				-- Run after the native tab layout exists so saved tab indexes line up.
				require("sessions.state").restore()
			end,
		},
		no_restore_cmds = {
			function()
				local project_state = require("project.state")
				local project_paths = require("project.paths")
				-- A dashboard picker can restore a project while AutoSession's
				-- delayed startup check is still pending. Its subsequent no-restore
				-- hook must not demote that successfully restored session to
				-- file-only mode.
				local root = project_paths.session_root()
				project_state.set_open(root ~= nil, root)
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
