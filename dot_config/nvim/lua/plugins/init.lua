-- keep foundational editor plugins in one load path.
return {
	----------------------------------------
	-- Core UX
	----------------------------------------
	{ "nvim-lua/plenary.nvim" }, -- lua helpers
	{ "nvim-tree/nvim-web-devicons" },
	----------------------------------------
	-- Git & coding aids
	----------------------------------------

	----------------------------------------
	-- LSP, diagnostics, formatting
	----------------------------------------

	{ "neovim/nvim-lspconfig" },

	----------------------------------------
	-- Python specifics
	----------------------------------------
	{ "linux-cultist/venv-selector.nvim", cmd = "VenvSelect", opts = { search_venv_managers = false } },
}
