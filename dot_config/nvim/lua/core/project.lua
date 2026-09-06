-- detect project roots and offer to turn a file-launched instance into a session.
local M = {}
local path_util = require("core.path")
local offered_roots = {}
local pending_roots = {}
local project_picker

local function session_list()
	local sessions = require("auto-session")
	return require("auto-session.lib").get_session_list(sessions.get_root_dir())
end

--- The loaded session as auto-session names it ("<root>" or "<root>|<branch>"),
--- unescaped back out of the on-disk path in v:this_session.
local function current_session_name()
	if vim.v.this_session == "" then
		return nil
	end

	local loaded, lib = pcall(require, "auto-session.lib")
	if not loaded then
		return nil
	end
	return lib.escaped_session_path_to_session_name(vim.v.this_session)
end

function M.set_open(value, root)
	vim.g.project_open = value == true
	if vim.g.project_open then
		vim.g.project_root = path_util.normalize(root) or vim.g.project_root or path_util.normalize(vim.uv.cwd())
		pending_roots = {}
		if project_picker then
			pcall(function()
				project_picker:close()
			end)
			project_picker = nil
		end
	else
		vim.g.project_root = nil
	end
end

function M.session_root()
	local session_name = current_session_name()
	if not session_name then
		return nil
	end

	local root = path_util.normalize(session_name:match("^([^|]+)"))
	return root and vim.fn.isdirectory(root) == 1 and root or nil
end

function M.is_open()
	return vim.g.project_open == true
end

function M.only(callback)
	return function(...)
		if not M.is_open() then
			return
		end
		return callback(...)
	end
end

M.root_markers = {
	".git",
	"package.json",
	"pyproject.toml",
	"Cargo.toml",
	"go.mod",
	"pom.xml",
	"build.gradle",
	"Makefile",
}

function M.root(path)
	path = path_util.normalize(path)
	if not path then
		return nil
	end

	local stat = vim.uv.fs_stat(path)
	local start = stat and stat.type == "directory" and path or vim.fs.dirname(path)
	return start and vim.fs.root(start, M.root_markers) or nil
end

function M.current_root()
	if M.is_open() then
		local root = M.session_root() or path_util.normalize(vim.g.project_root)
		if root then
			vim.g.project_root = root
			return root
		end
	end

	local buffer_path = vim.api.nvim_buf_get_name(0)
	if buffer_path ~= "" and not buffer_path:match("^%w+://") then
		local root = M.root(buffer_path)
		if root then
			return root
		end
	end

	return M.root(vim.uv.cwd())
end

function M.file_search_root()
	if M.is_open() then
		return M.current_root()
	end

	local buffer_path = vim.api.nvim_buf_get_name(0)
	if buffer_path ~= "" and not buffer_path:match("^%w+://") and vim.bo.buftype == "" then
		return vim.fs.dirname(path_util.normalize(buffer_path))
	end

	local cwd = path_util.normalize(vim.uv.cwd())
	local home = path_util.normalize(vim.uv.os_homedir())
	if cwd == "/" or cwd == home then
		return nil
	end
	return cwd
end

function M.contains(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	if path:match("^%w+://") then
		if not vim.startswith(path, "file://") then
			return false
		end
		local ok, filename = pcall(vim.uri_to_fname, path)
		if not ok then
			return false
		end
		path = filename
	end

	return path_util.under(path_util.normalize(path), M.current_root())
end

--- The workspace the servers attached to this buffer actually indexed: the
--- deepest LSP root or marker root that contains the file. Read back off the
--- clients that are about to answer the request, so a scope derived from this
--- can never point somewhere the results did not come from.
function M.buffer_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" or name:match("^%w+://") then
		return nil
	end

	local file = path_util.normalize(name)
	if not file then
		return nil
	end

	local candidates = path_util.lsp_roots(bufnr)
	local marker = path_util.clean(M.root(file))
	if marker then
		candidates[marker] = true
	end

	return path_util.longest_containing(candidates, file)
end

--- The root fS and gr scope to: the workspace whose server is about to answer
--- for this buffer, which is not always the open project.
---
--- Project mode wins only while the buffer actually belongs to the project.
--- Open a file from project B while project A is loaded and its client is
--- rooted at B (vim.lsp.start reuses a client only when the workspace folders
--- match), so every symbol comes back under B -- scoping those to A filters
--- the entire result set away and the picker looks empty. `fs` has no such
--- filter, which is why document symbols keep working when fS looks broken.
---
--- nil means unscoped, the honest answer for a buffer belonging to no project.
function M.picker_root(bufnr)
	local buffer_root = M.buffer_root(bufnr)

	if M.is_open() then
		local root = M.current_root()
		-- Nested workspace folders resolve deeper than the project root, so a
		-- sub-package still scopes to the whole project rather than itself.
		if root and buffer_root and path_util.under(buffer_root, root) then
			return root
		end
	end

	return buffer_root
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

local git_tools = {
	lazygit = {
		title = "Lazygit",
		command = { "lazygit" },
	},
	diff = {
		title = "Git Diff",
		-- The normal Git pager has `F`, which exits immediately when the output
		-- fits on one screen. Keep this window open until q is pressed instead.
		command = { "git", "-c", "core.pager=LESS=RQ delta", "diff" },
	},
	log = {
		title = "Serie",
		command = { "serie" },
	},
}

local function is_git_repo(root)
	local result = vim.system({ "git", "-C", root, "rev-parse", "--is-inside-work-tree" }, { text = true }):wait()
	return result.code == 0 and vim.trim(result.stdout or "") == "true"
end

function M.open_git_tool(name)
	if not M.is_open() then
		return false
	end

	local tool = git_tools[name]
	local root = M.current_root()
	if not tool or not root then
		return false
	end
	if not is_git_repo(root) then
		return false
	end

	if vim.fn.executable("kitty") ~= 1 or vim.fn.executable(tool.command[1]) ~= 1 then
		vim.notify(("Cannot open %s: required executable is missing"):format(tool.title), vim.log.levels.ERROR)
		return false
	end

	local title = ("%s · %s"):format(tool.title, vim.fn.fnamemodify(root, ":t"))
	local command = { "kitty", "--detach", "--directory", root, "--title", title }
	vim.list_extend(command, tool.command)

	local job = vim.fn.jobstart(command, { detach = true })
	if job <= 0 then
		vim.notify(("Failed to open %s in Kitty"):format(tool.title), vim.log.levels.ERROR)
		return false
	end

	return true
end

function M.open_session_window(session_name)
	if type(session_name) ~= "string" or session_name == "" then
		return false
	end

	local root = session_name:match("^([^|]+)")
	if not root or vim.fn.isdirectory(root) ~= 1 then
		root = vim.uv.cwd()
	end

	if vim.g.neovide then
		if vim.fn.executable("neovide") ~= 1 then
			vim.notify("Cannot open project window: Neovide is missing", vim.log.levels.ERROR)
			return false
		end

		local command, opts
		if vim.uv.os_uname().sysname == "Darwin" then
			-- Launch through the app bundle so macOS and OmniWM see Neovide's stable
			-- bundle ID. `-n` creates a separate GUI instance instead of forwarding
			-- the request to the Neovide window that owns this picker.
			if vim.fn.executable("open") ~= 1 then
				vim.notify("Cannot open project window: `open` is missing", vim.log.levels.ERROR)
				return false
			end
			local executable = vim.uv.fs_realpath(vim.fn.exepath("neovide")) or vim.fn.exepath("neovide")
			local bundle = executable:match("^(.*%.app)/Contents/MacOS/") or "Neovide"
			command = { "open", "-na", bundle, "--env", "NVIM_PROJECT_SESSION=" .. session_name }
			opts = { detach = true }
		else
			-- There is no bundle to route through elsewhere: every `neovide` call is
			-- already a separate process, so launch it directly and hand the session
			-- over in the environment, exactly as the Kitty branch below does.
			command = { "neovide", "--no-fork", "--", "--cmd", "cd " .. vim.fn.fnameescape(root) }
			opts = { detach = true, env = { NVIM_PROJECT_SESSION = session_name } }
		end

		local job = vim.fn.jobstart(command, opts)
		if job <= 0 then
			vim.notify("Failed to open project in a new Neovide window", vim.log.levels.ERROR)
			return false
		end
		return true
	end

	if vim.fn.executable("kitty") ~= 1 or vim.fn.executable("nvim") ~= 1 then
		vim.notify("Cannot open project window: Kitty or Neovim is missing", vim.log.levels.ERROR)
		return false
	end

	local title = ("Project · %s"):format(vim.fn.fnamemodify(root, ":t"))
	local command = { "kitty", "--detach", "--directory", root, "--title", title, "nvim" }
	local job = vim.fn.jobstart(command, {
		detach = true,
		env = { NVIM_PROJECT_SESSION = session_name },
	})
	if job <= 0 then
		vim.notify("Failed to open project in a new Kitty window", vim.log.levels.ERROR)
		return false
	end
	return true
end

function M.open_picked_session(session_name)
	if M.is_open() then
		return M.open_session_window(session_name)
	end
	return require("auto-session").autosave_and_restore(session_name)
end

-- Keep missing projects visible until explicitly pruned. An inaccessible
-- directory is not evidence that its saved session should be removed.
local function stale_session(item)
	local root = item.session_name:match("^([^|]+)")
	if not root then
		return false
	end
	local stat, _, code = vim.uv.fs_stat(root)
	return (stat and stat.type ~= "directory") or code == "ENOENT" or code == "ENOTDIR"
end

function M.prune_stale_sessions()
	local sessions = require("auto-session")
	local removed = 0
	for _, item in ipairs(session_list()) do
		if stale_session(item) and sessions.delete_session_file(item.path, item.display_name) then
			removed = removed + 1
		end
	end
	vim.notify(("Pruned %d stale project session%s"):format(removed, removed == 1 and "" or "s"))
	return removed
end

local function session_picker(title, confirm)
	return Snacks.picker.pick({
		title = title,
		format = function(item)
			return { { item.text, item.stale and "Comment" or "Normal" } }
		end,
		layout = { preset = "select" },
		actions = {
			prune_stale = function(picker)
				M.prune_stale_sessions()
				picker.list:set_selected()
				picker:find()
			end,
		},
		win = {
			input = { keys = { ["<c-x>"] = { "prune_stale", mode = { "n", "i" }, desc = "Prune stale projects" } } },
			list = { keys = { ["<c-x>"] = { "prune_stale", desc = "Prune stale projects" } } },
		},
		finder = function()
			return session_list()
		end,
		transform = function(item)
			item.stale = stale_session(item)
			item.text = item.display_name .. (item.stale and " (missing directory)" or "")
			item.file = item.path
		end,
		confirm = confirm,
	})
end

-- auto-session's own picker always restores in place. This one routes the
-- choice through open_picked_session, which opens a new Kitty window instead
-- when a project is already loaded here.
function M.pick_session()
	session_picker("Projects", function(picker, item)
		if item and stale_session(item) then
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

-- Sessions are keyed on root *and* branch (git_use_branch_name), so every
-- feature branch leaves one behind and nothing ever collects them. <Tab>
-- selects several and the picker re-finds rather than closing, so clearing out
-- a directory's worth is one visit.
--
-- delete_session_file, not delete_session: the list already carries the escaped
-- on-disk path, and re-deriving it from the name means re-entering
-- auto-session's private escaping. Deleting the session this instance has
-- loaded is auto-session's own special case -- it turns autosave off here and
-- says so -- so it is left alone rather than reimplemented.
function M.delete_session()
	session_picker("Delete project session", function(picker)
		local items = picker:selected({ fallback = true })
		if #items == 0 then
			picker:close()
			return
		end

		local sessions = require("auto-session")
		for _, item in ipairs(items) do
			sessions.delete_session_file(item.path, item.display_name)
		end
		picker.list:set_selected()
		picker:find()
	end)
end

local function startup_file()
	if vim.g.nvim_preview or vim.fn.argc() ~= 1 then
		return nil
	end

	local argument = vim.fn.argv(0)
	if type(argument) ~= "string" or argument == "" or argument == "-" or argument:match("^%w+://") then
		return nil
	end

	if vim.fn.isdirectory(argument) == 1 then
		return nil
	end

	return path_util.normalize(argument)
end

local function restore_in_progress()
	local loaded, sessions = pcall(require, "auto-session")
	return (loaded and sessions.restore_in_progress) or vim.g.SessionLoad == 1
end

local function git_branch(root)
	local result = vim.system({ "git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	local branch = vim.trim(result.stdout or "")
	return branch ~= "" and branch or nil
end

-- Session names are "<root>" or "<root>|<branch>", already unescaped and with
-- the legacy filename format folded in. Reading the list is what the session
-- picker does; rebuilding the on-disk name here instead meant depending on
-- auto-session's private escaping and its legacy fallback.
function M.session_exists(root)
	root = path_util.normalize(root)
	if not root then
		return false
	end

	local branch = git_branch(root) or ""
	for _, entry in ipairs(session_list()) do
		local entry_root, entry_branch = entry.session_name:match("^([^|]*)|?(.*)$")
		if path_util.normalize(entry_root) == root and entry_branch == branch then
			return true
		end
	end

	return false
end

function M.offer(file)
	file = path_util.normalize(file)
	local root = file and M.root(file) or nil
	if not file or not root or M.is_open() or restore_in_progress() then
		return false
	end
	if offered_roots[root] or pending_roots[root] then
		return false
	end

	local has_session = M.session_exists(root)
	pending_roots[root] = true
	vim.schedule(function()
		pending_roots[root] = nil
		if M.is_open() or restore_in_progress() then
			return
		end

		offered_roots[root] = true
		if has_session then
			M.open(file, root)
			return
		end

		local select = Snacks and Snacks.picker and Snacks.picker.select or vim.ui.select
		project_picker = select({ "Open project", "Keep file only" }, {
			prompt = ("Open as project `%s`?"):format(vim.fn.fnamemodify(root, ":t")),
		}, function(choice)
			project_picker = nil
			if choice == "Open project" then
				M.open(file, root)
			end
		end)
	end)

	return true
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
	M.set_open(false)
	vim.api.nvim_set_current_dir(root)
	M.set_open(true, root)

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
	if M.is_open() then
		local root = M.current_root()
		vim.notify(("Already in project `%s`"):format(root and vim.fn.fnamemodify(root, ":t") or "?"))
		return false
	end

	local name = vim.api.nvim_buf_get_name(0)
	local file = nil
	if name ~= "" and not name:match("^%w+://") and vim.bo.buftype == "" then
		file = path_util.normalize(name)
	end

	local root = M.root(file or vim.uv.cwd())
	if not root then
		vim.notify("No project root above this buffer", vim.log.levels.WARN)
		return false
	end

	return M.open(file, root)
end

--- Collapse the layout down to one window. Floats go first, since `:only`
--- leaves them behind; then the other tab pages, then the other windows. The
--- panels with teardown of their own (explorer, aerial, dapui, neotest) are
--- closed by the caller before this runs, so they are not merely hidden.
local function close_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	-- `:only` keeps whichever window is current, so pressing this from a scratch
	-- pane -- the info split, a leftover panel -- would make that pane the one
	-- survivor. Hand it a real file window to keep instead.
	if vim.bo.buftype ~= "" then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	end

	-- Silent because both are informational when there is nothing to close
	-- ("Already only one window"), and this runs off a key press.
	vim.cmd("silent! tabonly")
	vim.cmd("silent! only")
end

--- Back to what a freshly restored project looks like: one window, no buffers,
--- the file picker open. The session on disk is left alone, so this is a clean
--- slate to work from and not a discard. Modified buffers stay -- nothing here
--- is worth losing an edit over -- and so does anything outside the root, which
--- is why the layout is collapsed before the wipe rather than after: a window
--- left showing a kept buffer is the point.
function M.reset()
	local root = M.current_root()
	if not root then
		return false
	end

	close_windows()

	local kept = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].buflisted and M.contains(vim.api.nvim_buf_get_name(buf)) then
			if vim.bo[buf].modified then
				kept = kept + 1
			else
				pcall(vim.api.nvim_buf_delete, buf, {})
			end
		end
	end

	if kept > 0 then
		vim.notify(("Kept %d modified buffer%s"):format(kept, kept == 1 and "" or "s"), vim.log.levels.WARN)
	end

	Snacks.picker.files({ cwd = root })
	return true
end

--- The same project in a second window. open_session_window restores by session
--- name in the new instance, so save first: an unsaved project has no name to
--- hand over, and the macOS Neovide branch has no directory of its own to fall
--- back on if that restore fails.
function M.open_new_window()
	if not M.is_open() then
		return false
	end

	require("auto-session").save_session(nil, { show_message = false })
	local session_name = current_session_name()
	if not session_name then
		vim.notify("Cannot open a second window: this project has no session", vim.log.levels.ERROR)
		return false
	end

	return M.open_session_window(session_name)
end

--- A shell at the project root, the plain sibling of the git tools above. Not
--- gated on project mode: current_root() answers for a lone file too, and its
--- directory is still where a shell belongs.
function M.open_terminal()
	local root = M.current_root() or path_util.cwd()
	if not root then
		return false
	end

	if vim.fn.executable("kitty") ~= 1 then
		vim.notify("Cannot open a terminal: Kitty is missing", vim.log.levels.ERROR)
		return false
	end

	local title = ("Shell · %s"):format(vim.fn.fnamemodify(root, ":t"))
	local job = vim.fn.jobstart({ "kitty", "--detach", "--directory", root, "--title", title }, { detach = true })
	if job <= 0 then
		vim.notify("Failed to open a Kitty window", vim.log.levels.ERROR)
		return false
	end

	return true
end

--- The window holding a previous M.info() render, if one is still open.
local function info_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.b[vim.api.nvim_win_get_buf(win)].project_info then
			return win
		end
	end
end

--- Terminal escapes, so the tools' colored output lands as text. NO_COLOR is
--- set for them too; this is the belt to that pair of braces.
local function strip_ansi(text)
	return (text:gsub("\27%[[%d;?]*[ -/]*[@-~]", ""):gsub("\27%][^\7]*\7", ""))
end

--- Sized to the widest line it holds, since these are paths and tables read
--- across rather than down. Recomputed as the async blocks land.
local function fit_info_width(buf)
	local window = info_window()
	if not window then
		return
	end

	local width = 0
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	vim.api.nvim_win_set_width(window, math.min(math.max(width + 2, 40), 80))
end

--- `render` is the render this block belongs to. A second <leader>pi while an
--- onefetch is still walking the history would otherwise append that run's
--- output underneath the new one.
local function append_info(buf, render, lines)
	if not vim.api.nvim_buf_is_valid(buf) or vim.b[buf].project_info_render ~= render or #lines == 0 then
		return
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, vim.list_extend({ "" }, lines))
	vim.bo[buf].modifiable = false
	fit_info_width(buf)
end

--- The repository summary Kitty's cmd+shift+i shows, same tools, same flags,
--- same order. Both are handed `git rev-parse --show-toplevel` rather than the
--- project root: from a subdirectory onefetch reports the whole repo while
--- tokei counts only that subtree, so two different paths would print two
--- answers about two different trees. Their line counts still differ by design,
--- since onefetch counts only its default `programming markup` types.
---
--- Chained rather than run together, so the order is the script's order, and
--- async because onefetch walks the history -- the roots above are the part
--- worth having immediately, and they are already on screen when these land.
local function append_repo_stats(buf, render, toplevel)
	local tools = {
		{ "onefetch", "--no-art", "--no-color-palette", "--nerd-fonts", toplevel },
		{ "tokei", toplevel },
	}

	local function run(index)
		local cmd = tools[index]
		if not cmd then
			return
		end
		if vim.fn.executable(cmd[1]) ~= 1 then
			return run(index + 1)
		end

		vim.system(cmd, { text = true, env = { NO_COLOR = "1" } }, function(result)
			vim.schedule(function()
				local text = vim.trim((result.code == 0 and result.stdout or result.stderr) or "")
				if text == "" then
					text = ("%s exited %d with no output"):format(cmd[1], result.code)
				end
				append_info(buf, render, vim.split(strip_ansi(text), "\n", { plain = true }))
				run(index + 1)
			end)
		end)
	end

	run(1)
end

--- Every root this instance is holding, side by side. The scoping failures
--- this config has hit -- jdtls' cwd-named workspace, fS scoped to a root the
--- servers never indexed -- all look identical from the outside (an empty
--- picker) and all come apart the moment these are printed together.
---
--- A right-hand split rather than a notification: these are long paths read
--- against each other, and a toast that times out mid-comparison is the wrong
--- shape for that. Pressing the key again re-renders in place instead of
--- stacking a second pane. The repository summary follows once it arrives.
function M.info()
	-- Gathered before the split exists. Every one of these answers for the
	-- current buffer, which the scratch pane is about to become.
	local root = M.current_root()
	local lines = {
		("mode:        %s"):format(M.is_open() and "project" or "file only"),
		("root:        %s"):format(root or "none"),
		("cwd:         %s"):format(path_util.cwd() or "none"),
		("branch:      %s"):format((root and git_branch(root)) or "none"),
		("session:     %s"):format(current_session_name() or "not loaded"),
		("saved:       %s"):format(root and M.session_exists(root) and "yes" or "no"),
		("buffer root: %s"):format(M.buffer_root() or "none"),
		("picker root: %s"):format(M.picker_root() or "unscoped"),
	}

	local clients = vim.lsp.get_clients({ bufnr = 0 })
	table.insert(lines, ("clients:     %s"):format(#clients == 0 and "none" or ""))
	for _, client in ipairs(clients) do
		table.insert(lines, ("  %s  %s"):format(client.name, client.root_dir or "no root"))
	end

	local window = info_window()
	local buf
	if window then
		vim.api.nvim_set_current_win(window)
		buf = vim.api.nvim_win_get_buf(window)
	else
		buf = vim.api.nvim_create_buf(false, true)
		vim.b[buf].project_info = true
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "projectinfo"
		vim.api.nvim_buf_set_name(buf, "Project Info")
		-- `q` closes read-only panes here the way it closes a preview window;
		-- buffer-local, so macro recording is untouched everywhere else.
		vim.keymap.set("n", "q", "<C-w>c", { buffer = buf, desc = "Close project info" })

		vim.cmd("botright vsplit")
		vim.api.nvim_win_set_buf(0, buf)
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
		vim.wo.wrap = false
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	fit_info_width(buf)

	local render = (vim.b[buf].project_info_render or 0) + 1
	vim.b[buf].project_info_render = render
	if root then
		local toplevel = vim.system({ "git", "-C", root, "rev-parse", "--show-toplevel" }, { text = true }):wait()
		if toplevel.code == 0 then
			append_repo_stats(buf, render, vim.trim(toplevel.stdout or ""))
		end
	end

	return true
end

function M.setup()
	M.set_open(false)
	-- Only the log tool is bound here now. <leader>gg is Snacks.lazygit
	-- (plugins/init.lua) and <leader>gd is Diffview (core/keymaps.lua), both
	-- floats rather than Kitty windows; open_git_tool still knows how to launch
	-- either, so putting one back is a one-line change if the OS window turns
	-- out to be preferable.
	vim.keymap.set("n", "<leader>gl", function()
		M.open_git_tool("log")
	end, { desc = "Serie in Kitty" })
	vim.api.nvim_create_autocmd("BufEnter", {
		desc = "Offer project mode for files opened inside a project",
		callback = function(event)
			if vim.g.nvim_preview or vim.bo[event.buf].buftype ~= "" then
				return
			end
			local file = vim.api.nvim_buf_get_name(event.buf)
			if file ~= "" and not file:match("^%w+://") then
				M.offer(file)
			end
		end,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		desc = "Offer to open a file from its project session",
		once = true,
		callback = function()
			local requested_session = vim.env.NVIM_PROJECT_SESSION
			if requested_session and requested_session ~= "" then
				vim.env.NVIM_PROJECT_SESSION = nil
				M.set_open(true, requested_session:match("^([^|]+)"))
				vim.schedule(function()
					if
						not require("auto-session").restore_session(
							requested_session,
							{ is_startup_autorestore = true, show_message = false }
						)
					then
						M.set_open(false)
					end
				end)
				return
			end

			local argument = vim.fn.argc() == 1 and vim.fn.argv(0) or nil
			if argument and vim.fn.isdirectory(argument) == 1 then
				local root = M.root(argument)
				M.set_open(root ~= nil, root)
				return
			end

			local file = startup_file()
			if file then
				M.offer(file)
			end
		end,
	})
end

return M
