-- load one modular editor configuration for terminal, GUI, and preview modes.
-- Set by nvim-float.py for the read-only Neovide preview window; checked
-- by core.neovide (font size) and plugins/lazy specs (barbar, dashboard).
vim.g.nvim_preview = vim.env.NVIM_PREVIEW == "1"

require("core.options")
require("core.keymaps")
require("core.neovide")
require("core.lsp_log")

local theme_config = require("core.theme").sync_env_from_state()

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

require("lazy").setup({ import = "plugins" })

require("core.cmp")
require("core.project").setup()

-- Resolve theme from persisted dotfiles state, with env vars as fallback.
local nvim_colorscheme = theme_config.colorscheme
local nvim_background = theme_config.background -- nil, "dark", or "light"
local theme_transparent = theme_config.transparent

-- Only enable transparent background if theme metadata says it's ok
if theme_transparent and not vim.g.neovide then
	vim.api.nvim_create_augroup("TransparentBG", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		pattern = "*",
		group = "TransparentBG",
		callback = function()
			-- nvim_set_hl() replaces a group's whole definition rather than
			-- merging into it, so passing only {bg=...} would silently drop
			-- fg and any other attributes the colorscheme set. Fetch the
			-- resolved highlight first and clear just bg.
			for _, name in ipairs({ "Normal", "NormalNC", "LineNr", "SignColumn", "EndOfBuffer" }) do
				local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
				hl.bg = nil
				vim.api.nvim_set_hl(0, name, hl)
			end
		end,
	})
end

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
				require("core.dashboard").show()
			end)
		end
	end,
})

local readonly_libs = vim.api.nvim_create_augroup("readonly_libs", { clear = true })
local library_paths = require("core.library_paths")

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = readonly_libs,
	pattern = library_paths.autocmd_patterns,
	callback = function()
		vim.opt_local.modifiable = false
		vim.opt_local.readonly = true
	end,
})

-- Apply resolved theme
if nvim_background then
	vim.o.background = nvim_background
end
vim.cmd.colorscheme(nvim_colorscheme)
