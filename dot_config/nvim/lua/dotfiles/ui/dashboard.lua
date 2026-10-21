-- Two-step dashboard: a home view that looks the same in every directory, and a
-- project view opened from it with that project's actions and git context.
-- Opening a project view only changes what is drawn. Nothing chdirs or touches
-- a session until one of its actions runs, so Back is just a redraw.
local M = {}

local header = require("dotfiles.ui.dashboard_header")

-- Saved projects come from project-manager.nvim, which groups sessions by root
-- (this used to be ui/dashboard_session.lua). One render reads them several
-- times -- key checks and the project list -- so share the list until the
-- render's tick ends. A broken session store only hides entries.
local projects_cache
local function projects()
	if not projects_cache then
		local ok, list = pcall(require("project-manager.session").projects)
		projects_cache = ok and list or {}
		vim.schedule(function()
			projects_cache = nil
		end)
	end
	return projects_cache
end

--- One project's saved sessions, one per branch; empty when it has none.
local function project_sessions(root)
	for _, project in ipairs(projects()) do
		if project.root == root then
			return project.sessions
		end
	end
	return {}
end

--- The session project-manager would restore for `root` on its current branch.
local function current_session(root)
	local ok, entry = pcall(require("project-manager.session").find, root)
	return ok and entry or nil
end

--- The project the view has open; nil on the home view.
M.root = nil

-- Kept from the original module: core/autocmds.lua opens the dashboard here.
function M.show()
	if not (Snacks and Snacks.dashboard) then
		return
	end

	-- Snacks hides the tabline for the dashboard; nothing restores it once a
	-- real buffer takes over, so remember the value and put it back.
	local saved_tabline = vim.o.showtabline
	Snacks.dashboard()
	-- Cleared group, not just `once`: show() may run again before any BufEnter,
	-- and a second pending handler would restore a stale showtabline.
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("dashboard_tabline_restore", { clear = true }),
		once = true,
		desc = "Restore showtabline once a real buffer replaces the dashboard",
		callback = function()
			if vim.bo.filetype ~= "snacks_dashboard" then
				vim.o.showtabline = saved_tabline
			end
		end,
	})
end

local function dashboard_bufs()
	-- The Git Status terminal carries the dashboard filetype too; skip it.
	return vim.tbl_filter(function(buf)
		return vim.bo[buf].filetype == "snacks_dashboard" and vim.bo[buf].buftype ~= "terminal"
	end, vim.api.nvim_list_bufs())
end

function M.open(root)
	M.root = root
	Snacks.dashboard.update()
end

function M.back()
	M.root = nil
	Snacks.dashboard.update()
end

local group = vim.api.nvim_create_augroup("dotfiles_dashboard_views", { clear = true })
-- Snacks maps each render's keys but never unmaps the last render's, so a
-- project view's `d` would still delete a session from the home view.
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "SnacksDashboardUpdatePre",
	callback = function()
		for _, buf in ipairs(dashboard_bufs()) do
			for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
				if map.desc == "Dashboard action" then
					pcall(vim.keymap.del, "n", map.lhs, { buffer = buf })
				end
			end
		end
	end,
})
-- <BS> works as Back too; it is mapped here because a `<BS>` key column would
-- render as literal text in the menu.
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "SnacksDashboardUpdatePost",
	callback = function()
		if not M.root then
			return
		end
		for _, buf in ipairs(dashboard_bufs()) do
			vim.keymap.set("n", "<bs>", M.back, { buffer = buf, nowait = true, desc = "Dashboard action" })
		end
	end,
})
-- Coming back to the dashboard later (closing every buffer) starts at home,
-- not on whichever project was open an hour ago.
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "SnacksDashboardClosed",
	callback = function()
		M.root = nil
	end,
})

local function open_root(root)
	require("project-manager.launch").open_root(root)
end

local function pick_project()
	local items = {}
	for _, project in ipairs(projects()) do
		table.insert(items, {
			text = project.name .. " " .. vim.fn.fnamemodify(project.root, ":~"),
			name = project.name,
			root = project.root,
		})
	end
	Snacks.picker.pick({
		title = "Projects",
		items = items,
		layout = { preset = "select" },
		format = function(item)
			return { { item.name .. "  " }, { vim.fn.fnamemodify(item.root, ":~"), "Comment" } }
		end,
		-- Choosing a project opens its view rather than restoring straight away.
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					M.open(item.root)
				end)
			end
		end,
	})
end

local function home_keys()
	local keys = { gap = 1, padding = 1 }
	-- cwd_root() already prefers a cwd with its own saved session over the
	-- marker root, so `nvim` from a subdirectory still finds its project.
	local cwd_root = header.cwd_root()
	-- `s` opens the cwd's project view, where `s` again restores: `ss` restores.
	if cwd_root then
		table.insert(keys, {
			icon = " ",
			key = "s",
			desc = "Open " .. vim.fs.basename(cwd_root),
			action = function()
				M.open(cwd_root)
			end,
		})
	end
	vim.list_extend(keys, {
		{ icon = " ", key = "p", desc = "Find Project", action = pick_project },
		{
			icon = " ",
			key = "o",
			desc = "Open Directory",
			action = function()
				require("project-manager.picker").open_directory()
			end,
		},
		{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
		{
			icon = " ",
			key = "r",
			desc = "Recent Files",
			action = function()
				Snacks.picker.recent()
			end,
		},
		{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
	})
	return keys
end

local function project_list(limit)
	local items = {}
	for _, project in ipairs(projects()) do
		table.insert(items, {
			file = project.root,
			icon = "directory",
			autokey = true,
			action = function()
				M.open(project.root)
			end,
		})
		if #items >= limit then
			break
		end
	end
	return items
end

local function home()
	return {
		header.header(),
		home_keys(),
		{ pane = 2, icon = " ", title = "Projects", indent = 2, padding = 1, project_list(6) },
		-- Not scoped to the cwd: home is meant to look the same everywhere.
		{ pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
	}
end

local function pick_branch(root, current)
	local others = vim.tbl_filter(function(s)
		return not current or s.entry.session_name ~= current.session_name
	end, project_sessions(root))
	vim.ui.select(others, {
		prompt = "Restore branch session",
		format_item = function(s)
			return s.branch ~= "" and s.branch or "(no branch)"
		end,
	}, function(choice)
		if choice then
			require("project-manager.launch").open_session(choice.entry.session_name)
		end
	end)
end

local function project_keys(root)
	local current = current_session(root)
	local is_git = Snacks.git.get_root(root) ~= nil
	local branch_count = #project_sessions(root) - (current and 1 or 0)
	local keys = {
		gap = 1,
		padding = 1,
		-- open_root restores the current branch's session or starts a fresh one.
		{
			icon = " ",
			key = "s",
			desc = current and "Restore Session" or "Start Session",
			action = function()
				open_root(root)
			end,
		},
		{
			icon = " ",
			key = "b",
			desc = "Other Branches",
			enabled = branch_count > 0,
			action = function()
				pick_branch(root, current)
			end,
		},
		-- Pickers take the root as cwd so browsing a project never chdirs.
		{
			icon = " ",
			key = "f",
			desc = "Find Files",
			action = function()
				Snacks.picker.files({ cwd = root })
			end,
		},
		{
			icon = " ",
			key = "/",
			desc = "Grep",
			action = function()
				Snacks.picker.grep({ cwd = root })
			end,
		},
		{
			icon = " ",
			key = "g",
			desc = "Lazygit",
			enabled = is_git,
			action = function()
				Snacks.lazygit({ cwd = root })
			end,
		},
		{
			icon = " ",
			key = "d",
			desc = "Delete Session",
			enabled = current ~= nil,
			action = function()
				if vim.fn.confirm("Delete this project's session?", "&Yes\n&No", 2) == 1 then
					require("auto-session").delete_session_file(current.path, current.display_name)
					Snacks.dashboard.update()
				end
			end,
		},
		{ icon = " ", key = "-", desc = "Back", action = M.back },
		-- Same Quit as home: switching views unmaps home's `q`, which had
		-- replaced Snacks' own `q`, so without this entry q did nothing here.
		{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
	}
	return keys
end

local function project(root)
	return {
		header.header(),
		project_keys(root),
		-- One file list is enough: Recently Changed mostly repeated these rows.
		{ pane = 2, icon = " ", title = "Recent Files", section = "recent_files", cwd = root, indent = 2, padding = 1 },
		{
			pane = 2,
			icon = " ",
			title = "Git Status",
			-- Text rows instead of a terminal section, which printed "[Process exited 0]".
			indent = 2,
			padding = 1,
			header.status(5),
		},
		-- Commits sit at the bottom of the second pane, with their stats line
		-- under them as a summary; the wrapper hands stats its pane.
		{
			pane = 2,
			icon = " ",
			title = "Recent Commits",
			indent = 2,
			padding = 1,
			header.commits(5),
		},
		{ pane = 2, header.stats() },
	}
end

--- The current view's sections, rebuilt on every render.
function M.sections()
	-- A project deleted or moved while its view is open falls back to home.
	if M.root and vim.fn.isdirectory(M.root) ~= 1 then
		M.root = nil
	end
	return M.root and project(M.root) or home()
end

return M
