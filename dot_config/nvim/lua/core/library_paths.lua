-- classify dependency and toolchain files that are useful for navigation but
-- should not behave like editable project source.
local M = {}

M.autocmd_patterns = {
	"*/node_modules/*",
	"*/site-packages/*",
	"*/vendor/*",
	"*/homebrew/Cellar/*",
	"*/mise/installs/*",
	vim.fn.expand("~") .. "/go/*",
	vim.fn.expand("~") .. "/.rustup/toolchains/*/lib/*",
}

local path_patterns = vim.tbl_map(vim.fn.glob2regpat, M.autocmd_patterns)

function M.contains(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	path = vim.fs.normalize(path)
	for _, pattern in ipairs(path_patterns) do
		if vim.fn.match(path, pattern) >= 0 then
			return true
		end
	end

	return false
end

return M
