-- centralize machine-dependent roots for GUI Neovim processes.
local M = {}

local function parent(path)
	return path ~= "" and vim.fs.dirname(path) or nil
end

local function default_homebrew_prefix()
	if vim.env.HOMEBREW_PREFIX and vim.env.HOMEBREW_PREFIX ~= "" then
		return vim.env.HOMEBREW_PREFIX
	end

	local brew = vim.fn.exepath("brew")
	if brew ~= "" then
		return parent(parent(brew))
	end

	if vim.uv.os_uname().sysname == "Darwin" then
		return vim.uv.os_uname().machine == "arm64" and "/opt/homebrew" or "/usr/local"
	end
	return "/home/linuxbrew/.linuxbrew"
end

M.homebrew_prefix = default_homebrew_prefix()
M.applications_dir = vim.env.APPLICATIONS_DIR or "/Applications"

function M.homebrew(path)
	return vim.fs.joinpath(M.homebrew_prefix, path)
end

function M.application(name, path)
	local bundle = name:sub(-4) == ".app" and name or (name .. ".app")
	return vim.fs.joinpath(M.applications_dir, bundle, path or "")
end

return M
