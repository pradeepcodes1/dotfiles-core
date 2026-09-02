-- reveal the managed chezmoi source at its nearest project root, not the deployed target.
local M = {}
local library_paths = require("core.library_paths")
local ROOT_MARKERS = require("core.project").root_markers

local chezmoi_cache = {
	managed_paths = {},
}
local active_roots = {}
local active_paths = {}

local function normalize_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	return vim.fs.normalize(path)
end

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

	return normalize_path(path)
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

local function is_path_under_root(path, root)
	path = normalize_path(path)
	root = normalize_path(root)
	if not path or not root then
		return false
	end

	if path == root then
		return true
	end

	return vim.startswith(path, root .. "/")
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

	return normalize_path(output)
end

local function chezmoi_source_path(path)
	path = normalize_path(path)
	if not path then
		return nil
	end

	local cached = chezmoi_cache.managed_paths[path]
	if cached ~= nil then
		return cached or path
	end

	local home = normalize_path(vim.uv.os_homedir())
	if not home or not is_path_under_root(path, home) then
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

local function add_root_candidate(roots, root)
	root = normalize_path(root)
	if root then
		roots[root] = true
	end
end

local function lsp_root_for_path(bufnr, path)
	local roots = {}

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		add_root_candidate(roots, client.root_dir)
		if client.config then
			add_root_candidate(roots, client.config.root_dir)
		end

		local workspaces = client.workspace_folders or (client.config and client.config.workspace_folders)
		if type(workspaces) == "table" then
			for _, folder in ipairs(workspaces) do
				local root = folder.name
				if (not root or root == "") and folder.uri then
					local ok, fname = pcall(vim.uri_to_fname, folder.uri)
					if ok then
						root = fname
					end
				end
				add_root_candidate(roots, root)
			end
		end
	end

	local best_root
	for root in pairs(roots) do
		if is_path_under_root(path, root) and (not best_root or #root > #best_root) then
			best_root = root
		end
	end

	return best_root
end

local function target_for_buffer(bufnr)
	local path = chezmoi_source_path(source_buffer_path(bufnr))
	if not path then
		return nil, nil
	end

	local roots = {}
	add_root_candidate(roots, lsp_root_for_path(bufnr, path))
	add_root_candidate(roots, vim.fs.root(path, ROOT_MARKERS))

	local best_root
	for root in pairs(roots) do
		if is_path_under_root(path, root) and (not best_root or #root > #best_root) then
			best_root = root
		end
	end

	local root = best_root or normalize_path(vim.fs.dirname(path)) or normalize_path(vim.uv.cwd() or vim.fn.getcwd())

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

	return root or active_roots[vim.api.nvim_get_current_tabpage()] or normalize_path(vim.uv.cwd() or vim.fn.getcwd())
end

function M.show()
	local tabpage = vim.api.nvim_get_current_tabpage()
	local path, root = target_for_buffer(vim.api.nvim_get_current_buf())
	root = root or active_roots[tabpage] or normalize_path(vim.uv.cwd() or vim.fn.getcwd())
	active_roots[tabpage] = root
	active_paths[tabpage] = path
	execute(path, root)
end

function M.forget(tabpage)
	tabpage = tabpage or vim.api.nvim_get_current_tabpage()
	active_roots[tabpage] = nil
	active_paths[tabpage] = nil
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
