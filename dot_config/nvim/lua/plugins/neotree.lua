-- make Neo-tree cooperate with the shared Edgy sidebar and rich metadata columns.
-- Closing either pane closes the shared left edgebar, so the Explorer and
-- Symbols sidebar still comes and goes as one thing.
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
		opts = function()
			local columns = require("core.neotree_columns")

			return {
				sources = { "filesystem" },
				default_component_configs = {
					git_age = {
						width = 6,
						required_width = 78,
					},
					last_modified = {
						width = 6,
						required_width = 78,
					},
					owner_group = {
						width = 16,
						required_width = 116,
					},
					permissions = {
						width = 10,
						required_width = 92,
					},
					smart_size = {
						width = 9,
						required_width = 88,
					},
					type = {
						enabled = false,
					},
				},
				event_handlers = {
					{
						event = "file_added",
						handler = columns.handle_fs_change,
					},
					{
						event = "file_deleted",
						handler = columns.handle_fs_change,
					},
					{
						event = "file_moved",
						handler = columns.handle_fs_change,
					},
					{
						event = "file_renamed",
						handler = columns.handle_fs_change,
					},
					{
						event = "git_status_changed",
						handler = columns.invalidate_git_age,
					},
				},
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
					before_render = columns.before_render,
					bind_to_cwd = false,
					commands = {
						refresh = columns.refresh,
					},
					components = {
						git_age = columns.git_age,
						last_modified = columns.last_modified,
						owner_group = columns.owner_group,
						permissions = columns.permissions,
						smart_size = columns.smart_size,
					},
					filtered_items = {
						hide_dotfiles = false,
						hide_hidden = false,
					},
					hijack_netrw_behavior = "disabled",
					renderers = {
						directory = {
							{ "indent" },
							{ "icon" },
							{ "current_filter" },
							{
								"container",
								content = {
									{ "name", zindex = 10 },
									{
										"symlink_target",
										zindex = 10,
										highlight = "NeoTreeSymbolicLinkTarget",
									},
									{ "clipboard", zindex = 10 },
									{ "git_status", zindex = 20, align = "right", hide_when_expanded = true },
									{ "git_age", zindex = 20, align = "right" },
									{ "smart_size", zindex = 20, align = "right" },
									{ "last_modified", zindex = 20, align = "right" },
									{ "permissions", zindex = 20, align = "right" },
									{ "owner_group", zindex = 20, align = "right" },
								},
							},
						},
						file = {
							{ "indent" },
							{ "icon" },
							{
								"container",
								content = {
									{ "name", zindex = 10 },
									{
										"symlink_target",
										zindex = 10,
										highlight = "NeoTreeSymbolicLinkTarget",
									},
									{ "clipboard", zindex = 10 },
									{ "git_status", zindex = 20, align = "right" },
									{ "git_age", zindex = 20, align = "right" },
									{ "smart_size", zindex = 20, align = "right" },
									{ "last_modified", zindex = 20, align = "right" },
									{ "permissions", zindex = 20, align = "right" },
									{ "owner_group", zindex = 20, align = "right" },
								},
							},
						},
					},
				},
			}
		end,
	},
}
