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
	if vim.v.this_session == "" then
		return nil
	end

	local loaded, lib = pcall(require, "auto-session.lib")
	if not loaded then
		return nil
	end
	local session_name = lib.escaped_session_path_to_session_name(vim.v.this_session)
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
	if vim.fn.executable("kitty") ~= 1 or vim.fn.executable("nvim") ~= 1 then
		vim.notify("Cannot open project window: Kitty or Neovim is missing", vim.log.levels.ERROR)
		return false
	end

	local root = session_name:match("^([^|]+)")
	if not root or vim.fn.isdirectory(root) ~= 1 then
		root = vim.uv.cwd()
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

-- auto-session's own picker always restores in place. This one routes the
-- choice through open_picked_session, which opens a new Kitty window instead
-- when a project is already loaded here.
function M.pick_session()
	Snacks.picker.pick({
		title = "Projects",
		format = "text",
		layout = { preset = "select" },
		finder = function()
			return session_list()
		end,
		transform = function(item)
			item.text = item.display_name
			item.file = item.path
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					M.open_picked_session(item.session_name)
				end)
			end
		end,
	})
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

function M.open(file, root)
	file = path_util.normalize(file)
	root = path_util.normalize(root)
	if not file or not root then
		return false
	end

	-- Keep DirChangedPre from saving the file under the launch directory. Once
	-- cwd is the project root, allow this file-launched instance to autosave.
	M.set_open(false)
	vim.api.nvim_set_current_dir(root)
	M.set_open(true, root)

	local sessions = require("auto-session")
	if sessions.session_exists_for_cwd() then
		if not sessions.restore_session(nil, { is_startup_autorestore = true, show_message = false }) then
			vim.cmd.edit({ args = { file } })
			return false
		end
		-- The requested file is the reason for this launch. Keep the restored
		-- layout and buffers, but make that file the active buffer.
		vim.cmd.edit({ args = { file } })
		return true
	end

	-- Saving immediately makes the root visible in <leader>p without waiting
	-- for this Neovim instance to exit.
	return sessions.save_session(nil)
end

function M.setup()
	M.set_open(false)
	-- <leader>gg is Snacks.lazygit (plugins/init.lua), a float rather than a
	-- Kitty window. open_git_tool still knows how to launch lazygit, so putting
	-- it back is a one-line change if the OS window turns out to be preferable.
	vim.keymap.set("n", "<leader>gd", function()
		M.open_git_tool("diff")
	end, { desc = "Git diff in Kitty" })
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
