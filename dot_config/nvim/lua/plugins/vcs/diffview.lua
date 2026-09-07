return {
	"sindrets/diffview.nvim",
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewFileHistory",
		"DiffviewFocusFiles",
		"DiffviewToggleFiles",
		"DiffviewRefresh",
	},
	opts = {
		-- Missing diff sides use a buffer named null; name the view rather than that buffer.
		hooks = {
			view_opened = function(view)
				local name = view.class:name() == "FileHistoryView" and "File History" or "Diffview"
				vim.api.nvim_tabpage_set_var(view.tabpage, "tabname", name)
			end,
		},
		view = {
			default = {
				winbar_info = true,
			},
			merge_tool = {
				layout = "diff3_horizontal",
			},
			file_history = {
				winbar_info = true,
			},
		},
	},
}
