-- load one modular editor configuration for terminal, GUI, and preview modes.
-- Set by nvim-float.py for the read-only Neovide preview window; checked
-- by core.neovide (font size) and plugins/lazy specs (lualine, dashboard).
vim.g.nvim_preview = vim.env.NVIM_PREVIEW == "1"

require("core.options")
require("core.keymaps")
require("core.neovide")
require("lsp.lsp_log")

local theme = require("theme")
local theme_config = theme.prepare()

-- Bootstrap lazy.nvim if missing
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local clone_output = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=v11.17.5",
		"--single-branch",
		"https://github.com/folke/lazy.nvim",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.fn.delete(lazypath, "rf")
		error("Failed to clone lazy.nvim v11.17.5:\n" .. clone_output)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		{ import = "plugins" },
		{ import = "plugins.editor" },
		{ import = "plugins.layout" },
		{ import = "plugins.snacks" },
		{ import = "plugins.vcs" },
		{ import = "plugins.lsp" },
		{ import = "plugins.lsp-extras" },
		{ import = "plugins.tools" },
		{ import = "plugins.extras" },
		{ import = "plugins.theme" },
	},
})

require("project").setup()

-- When Neovim starts with a directory argument, cd into it and show dashboard
vim.api.nvim_create_autocmd("VimEnter", {
	desc = "Replace directory buffer with dashboard",
	pattern = "*",
	once = true,
	callback = function()
		if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
			vim.cmd.cd(vim.fn.argv(0))
			local buf = vim.api.nvim_get_current_buf()
			vim.schedule(function()
				vim.api.nvim_buf_delete(buf, { force = true })
				require("snacks.dashboard_controller").show()
			end)
		end
	end,
})

local readonly_libs = vim.api.nvim_create_augroup("readonly_libs", { clear = true })
local library_paths = require("lsp.library_paths")

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = readonly_libs,
	pattern = library_paths.autocmd_patterns,
	callback = function()
		vim.opt_local.modifiable = false
		vim.opt_local.readonly = true
	end,
})

-- Startup and live reload share the same application path. The startup
-- snapshot was prepared before plugins loaded so every consumer sees it.
theme.apply(theme_config)
