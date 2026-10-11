-- load one modular editor configuration for terminal, GUI, and preview modes.
-- Set by nvim-float.py for the read-only Neovide preview window; checked
-- by core.neovide (font size) and plugins/lazy specs (lualine, dashboard).
vim.g.nvim_preview = vim.env.NVIM_PREVIEW == "1"

-- Keymaps require project-manager.nvim before lazy.setup runs, so clone it into
-- lazy's own plugin directory on first start and put it on the rtp this early.
-- Lazy then manages updates there through plugins/tools/project-manager.lua.
local project_manager_path = vim.fn.stdpath("data") .. "/lazy/project-manager.nvim"
if not vim.uv.fs_stat(project_manager_path) then
	local clone_output = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/pradeepcodes1/project-manager.nvim",
		project_manager_path,
	})
	if vim.v.shell_error ~= 0 then
		vim.fn.delete(project_manager_path, "rf")
		error("Failed to clone project-manager.nvim:\n" .. clone_output)
	end
end
vim.opt.rtp:prepend(project_manager_path)

require("dotfiles.core.options")
require("dotfiles.keymaps")
require("dotfiles.core.neovide")

-- Nvim 0.12 makes lspconfig skip its legacy commands, so retain only the direct log opener.
vim.api.nvim_create_user_command("LspLog", function()
	vim.cmd.tabnew(vim.lsp.log.get_filename())
end, { desc = "Open the Nvim LSP client log" })

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

require("project-manager").setup()
require("dotfiles.core.autocmds")

-- Startup and live reload share the same application path. The startup
-- snapshot was prepared before plugins loaded so every consumer sees it.
theme.apply(theme_config)
