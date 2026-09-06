-- Use fff's persistent native index for the high-frequency file and text searches.
return {
	"dmtrKovalenko/fff",
	enabled = not vim.g.nvim_preview,
	build = function()
		require("fff.download").download_or_build_binary()
	end,
	opts = {
		-- Sessions restore their project after plugins are configured. Never let
		-- fff start a home-directory scan before the first picker supplies the
		-- resolved project root.
		enable_home_dir_scanning = false,
		layout = {
			prompt_position = "top",
		},
		keymaps = {
			close = { "<Esc>", "<C-c>" },
			move_up = { "<Up>", "<C-Up>", "<C-p>", "<C-k>" },
			move_down = { "<Down>", "<C-Down>", "<C-n>", "<C-j>" },
			cycle_previous_query = "<C-S-Up>",
			cycle_forward_query = "<C-S-Down>",
		},
		debug = {
			enabled = false,
			show_scores = false,
		},
	},
	lazy = false,
}
