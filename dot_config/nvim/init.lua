-- load one modular editor configuration for terminal, GUI, and preview modes.
-- Set by nvim-float.py for the read-only Neovide preview window; checked
-- by core.neovide (font size) and plugins/lazy specs (lualine, dashboard).
vim.g.nvim_preview = vim.env.NVIM_PREVIEW == "1"

require("dotfiles.core.options")
require("dotfiles.keymaps")
require("dotfiles.core.neovide")
require("dotfiles.lsp.lsp_log")

local theme = require("dotfiles.theme")
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
	-- One directory per concern. deps holds libraries nothing calls directly;
	-- the rest are named for what the plugin does to the editor, not for how it
	-- is wired -- there is no "extras" bucket to lose things in.
	spec = {
		{ import = "dotfiles.plugins.deps" },
		{ import = "dotfiles.plugins.ui" },
		{ import = "dotfiles.plugins.editor" },
		{ import = "dotfiles.plugins.lsp" },
		{ import = "dotfiles.plugins.git" },
		{ import = "dotfiles.plugins.tools" },
	},
	-- Chezmoi owns this tree; it changes via `chezmoi apply` and a restart,
	-- never by lazy noticing an edit. Drop the reloader and its file watcher.
	change_detection = { enabled = false },
	performance = {
		rtp = {
			-- matchit and matchparen stay enabled: nothing here replaces `%` on
			-- pairs or bracket-match highlighting.
			disabled_plugins = {
				"gzip",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})

require("dotfiles.project").setup()
require("dotfiles.core.autocmds")

-- Startup and live reload share the same application path. The startup
-- snapshot was prepared before plugins loaded so every consumer sees it.
theme.apply(theme_config)
