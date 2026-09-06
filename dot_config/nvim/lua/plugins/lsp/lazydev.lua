-- teach lua_ls that `vim` exists and what the Neovim API on it looks like.
--
-- nvim-lspconfig ships lua_ls with `settings.Lua` holding codeLens and hint
-- only; the runtime/workspace block that makes the editor's own API visible is
-- in that file as a *doc comment*, not as config. So a bare lua_ls sees these
-- files as plain Lua 5.4, and every `vim.` line opens with "Undefined global
-- `vim`". lazydev fills `workspace.library` in on the running client instead of
-- hardcoding it here, and does it lazily: a path is only handed to the server
-- once a file actually mentions the thing it defines, so opening one config
-- file does not make lua_ls index every installed plugin.
return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- vim.uv is luv, bound in at build time rather than written in Lua,
			-- so no amount of runtime path gets its types -- they come from the
			-- definitions lua_ls bundles under `${3rd}`.
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			-- snacks.nvim publishes itself as a bare `Snacks` global rather than
			-- a module you require, so nothing on the runtime path declares it --
			-- it is the one other undefined-global this config produces, in
			-- keymaps, project, references, the explorer and the dashboard.
			{ path = "snacks.nvim", words = { "Snacks" } },
			-- Every file under lua/plugins is a lazy.nvim spec, so let the
			-- `---@type LazySpec` annotations in them resolve too.
			{ path = "lazy.nvim", words = { "LazySpec" } },
		},
	},
}
