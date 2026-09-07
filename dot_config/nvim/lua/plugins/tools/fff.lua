-- Use fff's persistent native index for the high-frequency file and text searches.
local function move_half_page(direction)
	local picker = require("fff.picker_ui.picker_ui")
	local list_win = picker.state.list_win
	local height = list_win and vim.api.nvim_win_is_valid(list_win) and vim.api.nvim_win_get_height(list_win) or 2
	local move = direction == "up" and picker.move_up or picker.move_down

	-- Snacks moves by the list window's default half-page scroll distance.
	for _ = 1, math.max(1, math.floor(height / 2)) do
		move()
	end
end

return {
	"dmtrKovalenko/fff",
	enabled = not vim.g.nvim_preview,
	build = function()
		require("fff.download").download_or_build_binary()
	end,
	opts = {
		-- Keep the prompt recognizable without FFF's mascot glyph.
		prompt = " ",
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
			preview_scroll_up = "<C-b>",
			preview_scroll_down = "<C-f>",
			cycle_previous_query = "<C-S-Up>",
			cycle_forward_query = "<C-S-Down>",
		},
		-- Fff has no page-selection action, so provide the Snacks-style behavior
		-- as prompt mappings applied after its built-in preview-scroll mappings.
		mappings = {
			i = {
				["<C-u>"] = function()
					move_half_page("up")
				end,
				["<C-d>"] = function()
					move_half_page("down")
				end,
			},
			n = {
				["<C-u>"] = function()
					move_half_page("up")
				end,
				["<C-d>"] = function()
					move_half_page("down")
				end,
			},
		},
		debug = {
			enabled = false,
			show_scores = false,
		},
		git = {
			status_text_color = true,
		},
		-- FFF's groups lose their foreground after our colorscheme reloads.
		hl = {
			git_staged = "GitSignsAdd",
			git_modified = "GitSignsChange",
			git_deleted = "GitSignsDelete",
			git_renamed = "Special",
			git_untracked = "GitSignsAdd",
			git_ignored = "Comment",
		},
	},
	lazy = false,
}
