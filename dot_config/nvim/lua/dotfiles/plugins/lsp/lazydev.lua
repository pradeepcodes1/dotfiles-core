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
			-- The libraries below are loaded unconditionally rather than on a
			-- `words` match. `words` only inspects files that are *open*, so a
			-- workspace-wide diagnostic run still reports every `---@type
			-- LazySpec` and plugin config alias in the closed specs as an
			-- undefined doc name. These are small, and the aliases appear in
			-- nearly every file under plugins/ anyway.
			--
			-- lazy.nvim: `---@type LazySpec` on the specs themselves.
			{ path = "lazy.nvim" },
			-- Each spec annotates its `opts` with the plugin's own config class.
			{ path = "auto-session" },
			{ path = "blink.cmp" },
			{ path = "overseer.nvim" },
			-- hydra.nvim publishes the active hydra as `_G.Hydra`, annotated in
			-- its own source; the keymap and lualine reads of it are undefined
			-- fields on _G until those types are loaded.
			{ path = "hydra.nvim" },
		},
	},
}
