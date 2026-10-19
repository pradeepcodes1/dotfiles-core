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

-- Snacks pickers dim the editor with a blended black float behind them; give
-- fff's pickers the same backdrop so <leader>ff/<leader>fg match the rest.
local function open_backdrop(input_buf)
	if not vim.o.termguicolors then
		return
	end
	vim.api.nvim_set_hl(0, "DotfilesPickerBackdrop", { bg = "#000000" })
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = 0,
		col = 0,
		width = vim.o.columns,
		height = vim.o.lines,
		style = "minimal",
		border = "none",
		focusable = false,
		-- fff's lowest picker window (the preview) sits at zindex 51.
		zindex = 50,
	})
	vim.wo[win].winhighlight = "Normal:DotfilesPickerBackdrop"
	-- Snacks' default backdrop opacity.
	vim.wo[win].winblend = 60
	-- fff force-deletes its prompt buffer on every close path, so that is the
	-- one reliable signal to drop the backdrop with it.
	vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
		buffer = input_buf,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end,
	})
end

return {
	"dmtrKovalenko/fff",
	init = function()
		-- fff creates a fresh fff_input prompt buffer each time a picker opens.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "fff_input",
			group = vim.api.nvim_create_augroup("dotfiles_fff_backdrop", { clear = true }),
			callback = function(args)
				open_backdrop(args.buf)
			end,
		})
	end,
	enabled = not vim.g.nvim_preview,
	build = function()
		require("fff.download").download_or_build_binary()
	end,
	config = function(_, opts)
		require("fff").setup(opts)
		-- Terminal icons cannot grow past one text row, so give them an extra
		-- space of separation from the file name instead. Padding the icon itself
		-- keeps fff's own width and highlight offsets consistent.
		local name_renderer = require("fff.picker_ui.file_name_renderer")
		local build = name_renderer.build
		name_renderer.build = function(item, ctx, icon)
			return build(item, ctx, icon and (icon .. " "))
		end
	end,
	opts = {
		-- Keep the prompt recognizable without FFF's mascot glyph.
		prompt = "",
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
		git = {
			status_text_color = true,
		},
		-- FFF's groups lose their foreground after our colorscheme reloads.
		hl = {
			-- Use the same background for the prompt, results, preview, and their borders.
			normal = "DotfilesPickerNormal",
			border = "DotfilesPickerBorder",
			title = "DotfilesPickerTitle",
			-- Foreground-only matches remain visible on selected and preview rows.
			matched = "DotfilesPickerMatch",
			grep_match = "DotfilesPickerMatch",
			cursor = "Visual",
			git_staged = "GitSignsAdd",
			git_modified = "GitSignsChange",
			git_deleted = "GitSignsDelete",
			git_renamed = "Special",
			git_untracked = "GitSignsAdd",
			git_ignored = "Comment",
		},
	},
	-- Off the startup path, but still warmed before the first <leader>ff.
	event = "VeryLazy",
}
