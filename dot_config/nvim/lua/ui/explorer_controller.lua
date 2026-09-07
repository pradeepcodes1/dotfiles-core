-- Keep the Snacks explorer rooted at the managed source's nearest project root.
local M = {}
local cli = require("core.cli")
local library_paths = require("lsp.library_paths")
local path_util = require("core.path")
local ROOT_MARKERS = require("project.paths").root_markers

local chezmoi_cache = {
	managed_paths = {},
}
local active_roots = {}
local active_paths = {}
local session_open = {}

local function current_buffer_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return nil
	end

	if path:match("^%w+://") and not path:match("^file://") then
		return nil
	end

	if path:match("^file://") then
		local ok, fname = pcall(vim.uri_to_fname, path)
		if not ok then
			return nil
		end
		path = fname
	end

	return path_util.clean(path)
end

local function source_buffer_path(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" or vim.b[bufnr].snacks_scratch then
		return nil
	end

	local path = current_buffer_path(bufnr)
	if not path or library_paths.contains(path) then
		return nil
	end

	return path
end

local function chezmoi_source_path(path)
	path = path_util.clean(path)
	if not path then
		return nil
	end

	local cached = chezmoi_cache.managed_paths[path]
	if cached ~= nil then
		return cached or path
	end

	local home = path_util.clean(vim.uv.os_homedir())
	if not home or not path_util.under(path, home) then
		chezmoi_cache.managed_paths[path] = false
		return path
	end

	local source_path = path_util.clean(cli.capture({ "chezmoi", "source-path", path }))
	if source_path then
		chezmoi_cache.managed_paths[path] = source_path
		return source_path
	end

	chezmoi_cache.managed_paths[path] = false
	return path
end

-- The deepest root that still contains the file: an LSP workspace folder when
-- one claims it, otherwise the nearest marker directory, otherwise its parent.
local function target_for_buffer(bufnr)
	local path = chezmoi_source_path(source_buffer_path(bufnr))
	if not path then
		return nil, nil
	end

	local candidates = path_util.lsp_roots(bufnr)
	local marker_root = path_util.clean(vim.fs.root(path, ROOT_MARKERS))
	if marker_root then
		candidates[marker_root] = true
	end

	local root = path_util.longest_containing(candidates, path)
		or path_util.clean(vim.fs.dirname(path))
		or path_util.cwd()

	return path, root
end

local function explorer(tabpage)
	if tabpage ~= vim.api.nvim_get_current_tabpage() then
		return nil
	end

	return Snacks.picker.get({ source = "explorer" })[1]
end

local function reveal(picker, path, root)
	if picker:cwd() ~= root then
		picker:set_cwd(root)
	end

	if path then
		Snacks.explorer.reveal({ file = path })
	else
		picker:find()
	end
end

-- VimLeave can dismantle picker windows before auto-session asks for custom data.
-- Track the user's last open/close choice independently of the live window.
function M.session_state(tabs)
	local states = {}
	local tab_indexes = {}
	for index, tabpage in ipairs(tabs) do
		tab_indexes[tabpage] = index
		states[index] = {
			open = session_open[tabpage] == true,
		}
	end

	-- A live picker has the freshest cwd; tracked state remains the exit-time fallback.
	for _, picker in ipairs(Snacks.picker.get({ source = "explorer", tab = false })) do
		-- The list may be a float that follows the active tab; the layout root owns the split.
		local win = picker.layout and picker.layout.root and picker.layout.root.win
		local tabpage = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_tabpage(win) or nil
		local index = tabpage and tab_indexes[tabpage] or nil
		if index then
			-- The restored buffer remains the source of truth for the Explorer root.
			states[index] = { open = true }
		end
	end
	return states
end

function M.show(on_show)
	local tabpage = vim.api.nvim_get_current_tabpage()
	local path, root = target_for_buffer(vim.api.nvim_get_current_buf())
	root = root or active_roots[tabpage] or path_util.cwd()
	active_roots[tabpage] = root
	active_paths[tabpage] = path
	session_open[tabpage] = true

	local current = explorer(tabpage)
	if current then
		reveal(current, path, root)
		if on_show then
			on_show()
		end
		return
	end

	-- `enter = false`, not `focus = false`. Both suppress the focus steal on open
	-- -- picker.lua gates that on `focus ~= false and enter ~= false` -- but
	-- `focus` doubles as the name of the picker's home window, and the explorer
	-- source sets it to "list". Passing false there overwrites that name, so
	-- `M:focus()` resolves `win or self.opts.focus or "input"` down to the filter
	-- prompt, and the WinEnter handler on the layout box lands every later
	-- <C-w>h on the prompt instead of the tree. `enter` is read at that one gate
	-- and nowhere else.
	Snacks.explorer.open({
		cwd = root,
		enter = false,
		on_close = function()
			-- Shutdown is not a user request to forget that this tab had an Explorer.
			if vim.v.exiting == vim.NIL then
				session_open[tabpage] = false
			end
		end,
		on_show = function(picker)
			vim.b[picker.list.win.buf].snacks_explorer = true
			if path then
				Snacks.explorer.reveal({ file = path })
			end
			if on_show then
				on_show()
			end
		end,
	})
end

-- Reopening through show preserves the same root tracking and focus behavior as a manual toggle.
function M.restore(state, on_restored)
	if state and state.open then
		M.show(on_restored)
	elseif on_restored then
		on_restored()
	end
end

function M.close()
	local tabpage = vim.api.nvim_get_current_tabpage()
	local current = explorer(tabpage)
	session_open[tabpage] = false
	if current then
		current:close()
	end
end

function M.toggle()
	if explorer(vim.api.nvim_get_current_tabpage()) then
		M.close()
		return
	end

	M.show()
end

function M.close_all()
	M.close()
	pcall(vim.cmd, "AerialClose")
end

local follow_group = vim.api.nvim_create_augroup("snacks_explorer_follow_project_root", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
	group = follow_group,
	desc = "Follow source project roots in an open Snacks explorer",
	callback = function(args)
		local tabpage = vim.api.nvim_get_current_tabpage()
		vim.schedule(function()
			if not vim.api.nvim_tabpage_is_valid(tabpage) or vim.api.nvim_get_current_tabpage() ~= tabpage then
				return
			end
			if vim.api.nvim_get_current_buf() ~= args.buf then
				return
			end

			local current = explorer(tabpage)
			if not current then
				return
			end

			local path, root = target_for_buffer(args.buf)
			if not path or not root then
				return
			end
			if active_roots[tabpage] == root and active_paths[tabpage] == path then
				return
			end

			active_roots[tabpage] = root
			active_paths[tabpage] = path
			reveal(current, path, root)
		end)
	end,
})

return M
