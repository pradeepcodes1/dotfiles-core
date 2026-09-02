-- reveal the managed chezmoi source at its nearest project root, not the deployed target.
local M = {}
local library_paths = require("core.library_paths")
local path_util = require("core.path")
local ROOT_MARKERS = require("core.project").root_markers

local chezmoi_cache = {
	managed_paths = {},
}
local active_roots = {}
local active_paths = {}

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
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
		return nil
	end

	local path = current_buffer_path(bufnr)
	if not path or library_paths.contains(path) then
		return nil
	end

	return path
end

local function command_output(argv)
	local result = vim.system(argv, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end

	local output = (result.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if output == "" then
		return nil
	end

	return path_util.clean(output)
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

	local source_path = command_output({ "chezmoi", "source-path", path })
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

local function explorer_is_open(tabpage)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "neo-tree" and vim.b[buf].neo_tree_source == "filesystem" then
			return true
		end
	end

	return false
end

local function execute(path, root)
	local command = require("neo-tree.command")

	local args = {
		action = "show",
		toggle = false,
		source = "filesystem",
		position = "left",
		dir = root,
		selector = false,
	}

	if path then
		args.reveal_file = path
	end

	command.execute(args)
end

-- Shared with plugins/betterterm.lua, so the floating terminal opens on the
-- same project root the explorer reveals. Falls back the way M.show does:
-- buffers with no resolvable root (terminals, the dashboard) get the tab's
-- last explorer root, then Neovim's cwd.
function M.root_for_buffer(bufnr)
	local _, root = target_for_buffer(bufnr or vim.api.nvim_get_current_buf())

	return root or active_roots[vim.api.nvim_get_current_tabpage()] or path_util.cwd()
end

function M.show()
	local tabpage = vim.api.nvim_get_current_tabpage()
	local path, root = target_for_buffer(vim.api.nvim_get_current_buf())
	root = root or active_roots[tabpage] or path_util.cwd()
	active_roots[tabpage] = root
	active_paths[tabpage] = path
	execute(path, root)
end

local follow_group = vim.api.nvim_create_augroup("neotree_follow_project_root", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
	group = follow_group,
	desc = "Follow source project roots in an open Neo-tree explorer",
	callback = function(args)
		local tabpage = vim.api.nvim_get_current_tabpage()
		vim.schedule(function()
			if not vim.api.nvim_tabpage_is_valid(tabpage) or vim.api.nvim_get_current_tabpage() ~= tabpage then
				return
			end
			if vim.api.nvim_get_current_buf() ~= args.buf or not explorer_is_open(tabpage) then
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
			execute(path, root)
		end)
	end,
})

return M
