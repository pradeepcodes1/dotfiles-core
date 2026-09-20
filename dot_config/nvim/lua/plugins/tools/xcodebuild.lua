-- Load the Xcode workflow only for Apple source files or its explicit commands.
return {
	"wojciech-kulik/xcodebuild.nvim",
	enabled = vim.fn.has("mac") == 1 and not vim.g.nvim_preview,
	ft = { "swift", "objc", "objcpp" },
	cmd = {
		"XcodebuildSetup",
		"XcodebuildPicker",
		"XcodebuildBuild",
		"XcodebuildBuildRun",
		"XcodebuildRun",
	},
	dependencies = {
		"MunifTanjim/nui.nvim",
		"folke/snacks.nvim",
	},
	opts = {},
}
