-- define editor-wide behavior once before plugins specialize it.
-- core/options.lua
local opt = vim.opt
vim.filetype.add({
	pattern = {
		[".*%.py%.tmpl"] = "python",
		[".*%.toml%.tmpl"] = "toml",
	},
})

opt.number = true
opt.relativenumber = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.updatetime = 300
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.ignorecase = true
opt.cursorline = true
opt.wrap = false

-- Persistent undo
opt.undofile = true

-- Treesitter-based folding (start with all folds open)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99

-- Spell checking for prose
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "gitcommit", "text" },
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.spelllang = "en_us"
	end,
})

-- Smooth scrolling options
opt.scrolloff = 8 -- Keep 8 lines visible above/below cursor
opt.sidescrolloff = 8 -- Keep 8 columns visible left/right of cursor
opt.smoothscroll = true -- Enable smooth scrolling (Neovim 0.10+)

-- Report the terminal title so kitty tabs name themselves after the buffer
-- instead of showing the shell. Was disabled to avoid clashing with the tmux
-- status bar, which kitty's tab bar replaces.
-- Filename first: the tab bar is vertical, so leading text is what survives
-- truncation. "+" marks an unsaved buffer.
opt.title = true
if vim.g.nvim_preview then
	opt.titlestring = "Neovide Preview · %t"
else
	opt.titlestring = "%t%( %M%) · %{fnamemodify(getcwd(), ':t')}"
end
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.health = vim.tbl_deep_extend("force", vim.g.health or {}, { style = "float" })
-- format_on_save is handled by plugins/conform.lua
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	pattern = "*",
	command = "if mode() != 'c' | checktime | endif",
})

-- Restore terminal cursor to underscore on exit (prevents vim block cursor persisting)
if not vim.g.neovide then
	vim.api.nvim_create_autocmd("VimLeave", {
		callback = function()
			if #vim.api.nvim_list_uis() == 0 then
				return
			end

			vim.opt.guicursor = "a:hor20"
			io.write("\027[4 q")
		end,
	})
end
