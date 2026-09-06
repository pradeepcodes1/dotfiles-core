-- Copy useful context without disturbing the clipboard when it is unavailable.
local M = {}
local cli = require("core.cli")
local project_paths = require("project.paths")
local path_util = require("core.path")

local function file_path()
	local name = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or name == "" or name:match("^%w+://") then
		return nil
	end
	return path_util.normalize(name)
end

function M.value(kind)
	if kind == "project" then
		local root = project_paths.current_root()
		return root, "No project root available"
	end

	local file = file_path()
	if kind == "branch" or kind == "commit" then
		local root = file and vim.fs.dirname(file) or project_paths.current_root()
		if not root then
			return nil, "No Git repository available"
		end
		-- symbolic-ref rather than `rev-parse --abbrev-ref`: on a detached head
		-- the latter answers the literal "HEAD", which is not a branch to yank.
		local value = kind == "branch" and cli.git(root, "symbolic-ref", "--quiet", "--short", "HEAD")
			or cli.git(root, "rev-parse", "--verify", "HEAD")
		return value,
			kind == "branch" and "No Git branch available (outside a repository or detached HEAD)"
				or "No Git HEAD commit available"
	end

	if not file then
		return nil, "No named file in this buffer"
	end
	if kind == "absolute" then
		return file
	elseif kind == "filename" then
		return vim.fs.basename(file)
	elseif kind == "relative" then
		local root = project_paths.current_root()
		if not root or not path_util.under(file, root) then
			return nil, "Current file is outside the project or no project root is available"
		end
		return vim.fs.relpath(root, file)
	end
	return nil, "Unknown yank target"
end

function M.copy(kind)
	local value, err = M.value(kind)
	if not value then
		vim.notify(err, vim.log.levels.WARN)
		return
	end
	vim.fn.setreg("+", value, "v")
	vim.fn.setreg('"', value, "v")
	vim.notify("Copied: " .. value)
end

return M
