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
