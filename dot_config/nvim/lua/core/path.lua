-- one spelling of the path questions every module here ends up asking.
local M = {}

--- Absolute, symlink-resolved, forward-slashed. nil for anything unusable,
--- so callers can guard once instead of checking types.
function M.normalize(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	local absolute = vim.fn.fnamemodify(path, ":p")
	return vim.fs.normalize(vim.uv.fs_realpath(absolute) or absolute)
end

--- vim.fs.normalize only, for paths already known to be absolute and real.
--- Cheap enough to call per Neo-tree row, where normalize() is not.
function M.clean(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	return vim.fs.normalize(path)
end

--- Is `path` the root itself or inside it? The trailing slash matters:
--- without it "/tmp/foobar" counts as inside "/tmp/foo".
function M.under(path, root)
	path, root = M.clean(path), M.clean(root)
	if not path or not root then
		return false
	end

	return path == root or vim.startswith(path, root .. "/")
end

--- The deepest of `roots` that contains `path`. Language servers report
--- nested workspace folders, and the innermost one is the useful answer.
function M.longest_containing(roots, path)
	local best
	for root in pairs(roots) do
		if M.under(path, root) and (not best or #root > #best) then
			best = root
		end
	end

	return best
end

--- Every root the servers attached to `bufnr` claim, as a set. Clients report
--- these three ways and disagree about which they populate.
function M.lsp_roots(bufnr)
	local roots = {}

	local function add(root)
		root = M.clean(root)
		if root then
			roots[root] = true
		end
	end

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		add(client.root_dir)
		if client.config then
			add(client.config.root_dir)
		end

		local folders = client.workspace_folders or (client.config and client.config.workspace_folders)
		for _, folder in ipairs(type(folders) == "table" and folders or {}) do
			local root = folder.name
			if (not root or root == "") and folder.uri then
				local ok, fname = pcall(vim.uri_to_fname, folder.uri)
				root = ok and fname or nil
			end
			add(root)
		end
	end

	return roots
end

function M.cwd()
	return M.clean(vim.uv.cwd() or vim.fn.getcwd())
end

return M
