-- Editor-wide autocommands that belong to no single feature. Anything scoped to
-- one plugin or module is registered by that module instead.
--
-- Load position is load-bearing: init.lua requires this after project.setup()
-- and after lazy has run the auto-session spec, so their VimEnter handlers are
-- registered first and an explicitly launched project still wins over the
-- directory-argument dashboard below.

-- When Neovim starts with a directory argument, cd into it and show dashboard
local startup = vim.api.nvim_create_augroup("startup", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
	group = startup,
	desc = "Replace directory buffer with dashboard",
	pattern = "*",
	once = true,
	callback = function()
		if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
			vim.cmd.cd(vim.fn.argv(0))
			local buf = vim.api.nvim_get_current_buf()
			vim.schedule(function()
				vim.api.nvim_buf_delete(buf, { force = true })
				-- Directory starts use the same dashboard owner as the rest of the UI.
				require("dotfiles.ui.dashboard").show()
			end)
		end
	end,
})

local readonly_libs = vim.api.nvim_create_augroup("readonly_libs", { clear = true })
local library_paths = require("dotfiles.lsp.library_paths")

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = readonly_libs,
	desc = "Open dependency and toolchain sources read-only",
	pattern = library_paths.autocmd_patterns,
	callback = function()
		vim.bo.modifiable = false
		vim.bo.readonly = true
	end,
})
