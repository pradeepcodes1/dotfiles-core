-- make Neo-tree cooperate with the shared Edgy sidebar.
--
-- There are no custom renderers or columns here any more. This config used to
-- add five metadata columns -- git age, directory sizes, mtime, permissions,
-- owner/group -- backed by core/neotree_columns.lua. None of them ever drew
-- anything: neo-tree skips a component whose `required_width` exceeds the
-- window width, those columns asked for 78 to 116, and this explorer is pinned
-- at 40 to share one edgebar with the symbol outline. Dropping them also drops
-- the hand-written renderers, so neo-tree's defaults apply -- which cover the
-- same components and add diagnostics and modified markers.
local function close_sidebar()
	require("edgy").close("left")
end

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		enabled = not vim.g.nvim_preview,
		branch = "v3.x",
		cmd = "Neotree",
		dependencies = {
			-- plenary and devicons are already declared in plugins/init.lua
			"MunifTanjim/nui.nvim",
		},
		opts = {
			sources = { "filesystem" },
			source_selector = {
				winbar = false,
				statusline = false,
			},
			-- Matches the left edgebar width in plugins/edgy.lua; keep the two
			-- in sync or the column resizes when the Explorer opens.
			window = {
				width = 40,
				mappings = {
					["q"] = close_sidebar,
					["<C-q>"] = close_sidebar,
					["Q"] = close_sidebar,
					["<leader>x"] = close_sidebar,
					["<C-w>c"] = close_sidebar,
					["<C-w>q"] = close_sidebar,
				},
			},
			filesystem = {
				bind_to_cwd = false,
				filtered_items = {
					hide_dotfiles = false,
					hide_hidden = false,
				},
				hijack_netrw_behavior = "disabled",
			},
		},
	},
}
