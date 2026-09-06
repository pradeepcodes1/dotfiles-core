local M = {}

local pruner = require("project.actions.pruner")
local project_state = require("project.state")
local project_paths = require("project.paths")
local cli = require("core.cli")
local path_util = require("core.path")

local function session_picker(title, confirm)
	return Snacks.picker.pick({
		title = title,
		format = function(item)
			return { { item.text, item.stale and "Comment" or "Normal" } }
		end,
		layout = { preset = "select" },
		actions = {
			prune_stale = function(picker)
				pruner.prune_stale_sessions()
				picker.list:set_selected()
				picker:find()
			end,
		},
		win = {
			input = { keys = { ["<c-x>"] = { "prune_stale", mode = { "n", "i" }, desc = "Prune stale projects" } } },
			list = { keys = { ["<c-x>"] = { "prune_stale", desc = "Prune stale projects" } } },
		},
		finder = function()
			return project_state.session_list()
		end,
		transform = function(item)
			item.stale = pruner.stale_session(item)
			item.text = item.display_name .. (item.stale and " (missing directory)" or "")
			item.file = item.path
		end,
		confirm = confirm,
	})
end

M.session_picker = session_picker

function M.open_session_window(session_name)
	if type(session_name) ~= "string" or session_name == "" then
		return false
	end

	local root = session_name:match("^([^|]+)")
	if not root or vim.fn.isdirectory(root) ~= 1 then
		root = vim.uv.cwd()
	end

	if vim.g.neovide then
		if cli.missing("open project window", "neovide") then
			return false
		end

		local command, opts
		if vim.uv.os_uname().sysname == "Darwin" then
			-- Launch through the app bundle so macOS and OmniWM see Neovide's stable
			-- bundle ID. `-n` creates a separate GUI instance instead of forwarding
			-- the request to the Neovide window that owns this picker.
			if cli.missing("open project window", "open") then
				return false
			end
			local executable = vim.uv.fs_realpath(vim.fn.exepath("neovide")) or vim.fn.exepath("neovide")
			local bundle = executable:match("^(.*%.app)/Contents/MacOS/") or "Neovide"
			command = { "open", "-na", bundle, "--env", "NVIM_PROJECT_SESSION=" .. session_name }
			opts = {}
		else
			-- There is no bundle to route through elsewhere: every `neovide` call is
			-- already a separate process, so launch it directly and hand the session
			-- over in the environment, exactly as the Kitty branch below does.
			command = { "neovide", "--no-fork", "--", "--cmd", "cd " .. vim.fn.fnameescape(root) }
			opts = { env = { NVIM_PROJECT_SESSION = session_name } }
		end

		return cli.detach("open project in a new Neovide window", command, opts)
	end

	if cli.missing("open project window", "kitty", "nvim") then
		return false
	end

	local title = ("Project · %s"):format(vim.fn.fnamemodify(root, ":t"))
	return cli.detach("open project in a new Kitty window", cli.kitty_argv(root, title, "nvim"), {
		env = { NVIM_PROJECT_SESSION = session_name },
	})
end

function M.open_picked_session(session_name)
	if project_state.is_open() then
		return M.open_session_window(session_name)
	end
	return require("auto-session").autosave_and_restore(session_name)
end

-- auto-session's own picker always restores in place. this one routes the
-- choice through open_picked_session, which opens a new kitty window instead
-- when a project is already loaded here.
function M.pick_session()
	session_picker("Projects", function(picker, item)
		if item and pruner.stale_session(item) then
			vim.notify("Project directory is missing. Press Ctrl-X to prune stale entries.", vim.log.levels.WARN)
			return
		end
		picker:close()
		if item then
			vim.schedule(function()
				M.open_picked_session(item.session_name)
			end)
		end
	end)
end

-- Symbol and reference pickers are scoped to the project, which is what keeps
-- jdtls' decompiled jdt:// classfiles, dependency sources and toolchain
-- libraries out of them. <C-.> widens the picker to everything the servers
-- actually index, for the times a JDK or library symbol is the thing you want.
--
-- No action is written for this: Snacks generates a `toggle_<name>` action for
-- every entry in `toggles`, which flips `picker.opts[name]` and re-finds. The
-- item predicate cannot see the picker, so `transform` -- which can -- copies
-- the flag onto the filter's own meta and returns true to force the refresh.
-- `root` is required, and a nil one means unscoped rather than "fall back to
-- current_root()". That fallback would scope a file belonging to no project to
-- whatever repo Neovim happened to start in, filtering away every result the
-- server returned -- the exact failure this is supposed to prevent.
function M.picker_scope(root)
	if not root then
		return {}
	end

	return {
		toggles = { external = { icon = "e" } },
		-- Deliberately `transform` and not `filter.cwd`. Only the location
		-- sources apply the picker's Filter -- lsp/init.lua calls filter:match
		-- inside get_locations, which serves gr -- while the symbol finder
		-- ignores it entirely, so a filter here would scope gr and silently do
		-- nothing for fS. Finder:run applies `transform` for every source, and
		-- returning false from it drops the item.
		transform = function(item, ctx)
			if ctx.picker.opts.external then
				return
			end
			if not path_util.under(item.file, root) then
				return false
			end
		end,
		win = {
			input = { keys = { ["<c-.>"] = { "toggle_external", mode = { "i", "n" } } } },
			list = { keys = { ["<c-.>"] = "toggle_external" } },
		},
	}
end

--- The same project in a second window. open_session_window restores by session
--- name in the new instance, so save first: an unsaved project has no name to
--- hand over, and the macOS Neovide branch has no directory of its own to fall
--- back on if that restore fails.
function M.open_new_window()
	if not project_state.is_open() then
		return false
	end

	require("auto-session").save_session(nil, { show_message = false })
	local session_name = project_state.current_session_name()
	if not session_name then
		vim.notify("Cannot open a second window: this project has no session", vim.log.levels.ERROR)
		return false
	end

	return M.open_session_window(session_name)
end

--- A shell at the project root, opened as a detached Kitty window. Not
--- gated on project mode: current_root() answers for a lone file too, and its
--- directory is still where a shell belongs.
function M.open_terminal()
	local root = project_paths.current_root() or path_util.cwd()
	if not root then
		return false
	end

	if cli.missing("open a terminal", "kitty") then
		return false
	end

	local title = ("Shell · %s"):format(vim.fn.fnamemodify(root, ":t"))
	return cli.detach("open a Kitty window", cli.kitty_argv(root, title))
end

--- `file` is the buffer the launch was about, kept as the active buffer across
--- the restore. open_current passes nil for a directory-launched instance,
--- where the project itself is the whole request.
function M.open(file, root)
	file = path_util.normalize(file)
	root = path_util.normalize(root)
	if not root then
		return false
	end

	-- Keep DirChangedPre from saving the file under the launch directory. Once
	-- cwd is the project root, allow this file-launched instance to autosave.
	project_state.set_open(false)
	vim.api.nvim_set_current_dir(root)
	project_state.set_open(true, root)

	local sessions = require("auto-session")
	if sessions.session_exists_for_cwd() then
		local restored = sessions.restore_session(nil, { is_startup_autorestore = true, show_message = false })
		-- The requested file is the reason for this launch. Keep the restored
		-- layout and buffers, but make that file the active buffer.
		if file then
			vim.cmd.edit({ args = { file } })
		end
		return restored == true
	end

	-- Saving immediately makes the root visible in <leader>pp without waiting
	-- for this Neovim instance to exit.
	return sessions.save_session(nil)
end

--- Turn a file-launched instance into a project from the current buffer. The
--- BufEnter offer fires once per root (offered_roots latches), so declining it
--- -- or landing in a root the offer never covered -- otherwise leaves no way
--- into project mode short of restarting Neovim.
function M.open_current()
	if project_state.is_open() then
		local root = project_paths.current_root()
		vim.notify(("Already in project `%s`"):format(root and vim.fn.fnamemodify(root, ":t") or "?"))
		return false
	end

	local name = vim.api.nvim_buf_get_name(0)
	local file = nil
	if name ~= "" and not name:match("^%w+://") and vim.bo.buftype == "" then
		file = path_util.normalize(name)
	end

	local root = project_paths.root(file or vim.uv.cwd())
	if not root then
		vim.notify("No project root above this buffer", vim.log.levels.WARN)
		return false
	end

	return M.open(file, root)
end

return M
