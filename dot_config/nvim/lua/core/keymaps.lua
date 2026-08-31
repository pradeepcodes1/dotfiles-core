-- keep cross-plugin navigation and actions in one discoverable key layer.
local map = vim.keymap.set
local diagnostics = require("core.diagnostics")
local problems = require("core.problems")
local quickfix = require("core.quickfix")
vim.g.mapleader = " "

local function format_symbol_name(item, filetype)
	local symbol_path = {}
	local current = item
	while current do
		table.insert(symbol_path, 1, current.name)
		current = current.parent
	end

	if filetype == "json" or filetype == "yaml" then
		return table.concat(symbol_path, ".")
	end

	return symbol_path[#symbol_path]
end

local function symbol_type_label(bufnr, symbol_type)
	local ok_aerial_config, aerial_config = pcall(require, "aerial.config")
	local label = (symbol_type or "Unknown"):lower()
	if ok_aerial_config then
		local icon = aerial_config.get_icon(bufnr, symbol_type or "Unknown")
		if icon and icon ~= "" then
			label = string.format("%s %s", icon, label)
		end
	end
	return label
end

local function document_symbol_picker(opts)
	opts = opts or {}

	local conf = require("telescope.config").values
	local entry_display = require("telescope.pickers.entry_display")
	local finders = require("telescope.finders")
	local pickers = require("telescope.pickers")

	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local filetype = vim.bo[bufnr].filetype

	require("aerial").sync_load()
	local backends = require("aerial.backends")
	local data = require("aerial.data")

	local backend = backends.get()
	if not backend then
		backends.log_support_err()
		return
	elseif not data.has_symbols(bufnr) then
		backend.fetch_symbols_sync(bufnr, opts)
	end

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = opts.symbol_width or 30 },
			{ remaining = true },
		},
	})

	local function make_entry(item)
		local symbol_name = format_symbol_name(item, filetype)
		local symbol_type = item.kind or "Unknown"
		local type_label = symbol_type_label(bufnr, symbol_type)
		local lnum = item.selection_range and item.selection_range.lnum or item.lnum
		local col = item.selection_range and item.selection_range.col or item.col

		return {
			value = item,
			ordinal = string.format("%s %s", symbol_name, symbol_type:lower()),
			display = function(entry)
				return displayer({
					entry.symbol_name,
					entry.type_label,
				})
			end,
			symbol_name = symbol_name,
			type_label = type_label,
			filename = filename,
			lnum = lnum,
			col = col + 1,
		}
	end

	local results = {}
	local default_selection_index = 1
	if data.has_symbols(bufnr) then
		local bufdata = data.get_or_create(bufnr)
		local position = bufdata.positions[bufdata.last_win]
		for _, item in bufdata:iter({ skip_hidden = false }) do
			table.insert(results, item)
			if position and item == position.closest_symbol then
				default_selection_index = #results
			end
		end
	end

	local sorting_strategy = opts.sorting_strategy or conf.sorting_strategy
	if sorting_strategy == "descending" then
		local reversed = {}
		for index = #results, 1, -1 do
			table.insert(reversed, results[index])
		end
		results = reversed
		default_selection_index = #results - (default_selection_index - 1)
	end

	pickers
		.new(opts, {
			prompt_title = "Document Symbols",
			finder = finders.new_table({
				results = results,
				entry_maker = make_entry,
			}),
			default_selection_index = default_selection_index,
			sorter = conf.generic_sorter(opts),
			previewer = conf.qflist_previewer(opts),
			push_cursor_on_edit = true,
		})
		:find()
end

local function workspace_symbol_entry_maker(opts)
	local entry_display = require("telescope.pickers.entry_display")
	local make_entry = require("telescope.make_entry")
	local telescope_utils = require("telescope.utils")
	local base_entry_maker = make_entry.gen_from_lsp_symbols(opts)
	local hidden = telescope_utils.is_path_hidden(opts)

	local display_items = {
		{ width = opts.symbol_width or 25 },
		{ remaining = true },
	}

	if not hidden then
		table.insert(display_items, 2, { width = vim.F.if_nil(opts.fname_width, 30) })
	end

	local displayer = entry_display.create({
		separator = " ",
		hl_chars = { ["["] = "TelescopeBorder", ["]"] = "TelescopeBorder" },
		items = display_items,
	})

	return function(item)
		local entry = base_entry_maker(item)
		if not entry then
			return nil
		end

		local symbol_type = entry.symbol_type or "Unknown"
		local symbol_label = symbol_type_label(0, symbol_type)

		entry.display = function(current_entry)
			if hidden then
				return displayer({
					current_entry.symbol_name,
					symbol_label,
				})
			end

			local filename_display = telescope_utils.transform_path(opts, current_entry.filename)
			local icon
			local icon_highlight
			filename_display, icon_highlight, icon =
				telescope_utils.transform_devicons(current_entry.filename, filename_display, opts.disable_devicons)

			local display, highlights = displayer({
				current_entry.symbol_name,
				filename_display,
				symbol_label,
			})

			if icon_highlight and icon and icon ~= "" then
				local icon_start = display:find(filename_display, 1, true)
				highlights = highlights or {}
				if icon_start then
					table.insert(highlights, { { icon_start - 1, icon_start - 1 + #icon }, icon_highlight })
				end
			end

			return display, highlights
		end

		return entry
	end
end

-- basics
map("i", "jk", "<Esc>", { desc = "Exit insert mode with jk" })
map("v", "jk", "<Esc>", { desc = "Exit visual mode with jk" })
map("t", "<C-Space>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
map("v", "q", "<Esc>", { desc = "Exit visual mode with q" })
-- Telescope
if not vim.g.nvim_preview then
	map("n", "<leader>ff", function()
		require("telescope.builtin").find_files({
			previewer = false,
			layout_config = {
				width = 0.45,
			},
		})
	end, { desc = "Find Files (no preview)" })
	map("n", "<leader>fg", ":Telescope live_grep<CR>", { desc = "Grep" })
	map("n", "<leader>/", ":Telescope current_buffer_fuzzy_find<CR>", { desc = "Smart buffer search (symbols/fuzzy)" })
	map("n", "<leader>fs", function()
		local bufname = vim.api.nvim_buf_get_name(0)
		local is_virtual = bufname:match("^%w+://") and not bufname:match("^file://")
		document_symbol_picker({
			previewer = not is_virtual,
			layout_config = is_virtual and { width = 0.35 } or nil,
		})
	end, { desc = "Find symbols in file" })
	map("n", "<leader>fS", function()
		local opts = {}
		opts.entry_maker = workspace_symbol_entry_maker(opts)
		local builtin = require("telescope.builtin")
		if builtin.lsp_dynamic_workspace_symbols then
			builtin.lsp_dynamic_workspace_symbols(opts)
		else
			builtin.lsp_workspace_symbols(opts)
		end
	end, { desc = "Find symbols in workspace" })
	map("n", "<leader>fr", ":Telescope oldfiles<CR>", { desc = "Recent files" })
	map("n", "<leader>`", ":Telescope buffers<CR>", { desc = "Search open buffers" })
end
-- LSP (gd, rename, code_action are in lsp/common.lua on_attach)
map("n", "<leader>lc", quickfix.close, { desc = "Close quickfix view" })
map("n", "?", diagnostics.open_line_float, { desc = "Open diagnostic float" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
map("n", "<leader>lh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })
map("n", "<leader>vp", problems.toggle_workspace_float, { desc = "View: Problems (float)" })
map("n", "<leader>vP", problems.toggle_buffer_float, { desc = "View: Problems (buffer float)" })
map("n", "<leader>vq", quickfix.toggle_float, { desc = "View: Quickfix (float)" })
map("n", "<leader>vr", problems.refresh_workspace, { desc = "View: Refresh Problems" })
map("n", "<leader>ud", function()
	vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Toggle diagnostics" })
map("n", "[[", function()
	local ok, aerial = pcall(require, "aerial")
	if ok then
		local ok_symbols, symbols = pcall(aerial.get_location, false)
		if ok_symbols and symbols and #symbols > 1 then
			aerial.prev_up()
			return
		end
	end

	vim.cmd("normal! [[")
end, { desc = "Parent symbol" })

-- Show dashboard and restore tabline when leaving it
function _G._show_dashboard()
	if Snacks and Snacks.dashboard then
		local saved_tabline = vim.o.showtabline
		Snacks.dashboard()
		vim.api.nvim_create_autocmd("BufEnter", {
			once = true,
			callback = function()
				if vim.bo.filetype ~= "snacks_dashboard" then
					vim.o.showtabline = saved_tabline
				end
			end,
		})
	end
end

-- Split navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to split above" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to split below" })
map("n", "<leader>w<Left>", "<Cmd>vertical resize -10<CR>", { desc = "Resize split narrower" })
map("n", "<leader>w<Right>", "<Cmd>vertical resize +10<CR>", { desc = "Resize split wider" })
map("n", "<leader>w<Up>", "<Cmd>resize +10<CR>", { desc = "Resize split taller" })
map("n", "<leader>w<Down>", "<Cmd>resize -10<CR>", { desc = "Resize split shorter" })
map("n", "<leader>w=", "<C-w>=", { desc = "Equalize splits" })

local opts = { noremap = true, silent = true }

-- BarBar keymaps; unavailable in preview mode (barbar.nvim disabled there,
-- see plugins/barbar.lua) — skip registering to avoid dangling E492 errors.
if not vim.g.nvim_preview then
	map("n", "<leader>bk", "<Cmd>BufferPick<CR>", opts)
	map("n", "<leader>q", function()
		vim.cmd("BufferClose")
		vim.schedule(function()
			local remaining = vim.tbl_filter(function(b)
				return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= ""
			end, vim.api.nvim_list_bufs())
			if #remaining == 0 then
				_show_dashboard()
			end
		end)
	end, { noremap = true, silent = true, desc = "Close buffer (dashboard if last)" })
end

-- Project management
map("n", "<leader>p", function()
	require("telescope").extensions.projects.projects({})
end, { desc = "Projects" })

-- Splits
map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>\\", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>x", "<C-w>c", { desc = "Close split" })

-- Stop search highlighting and disable bare-q macro recording; in preview
-- mode (single read-only buffer, see nvim-float.py) map it to quit instead,
-- matching the old bat-pager "q to close" behavior this replaced.
if vim.g.nvim_preview then
	map("n", "q", ":qa<CR>", { desc = "Quit preview" })
else
	map("n", "q", ":nohlsearch<CR><Esc>", { desc = "Clear search highlighting" })
end

map("i", "<A-Left>", "<C-o>b", opts) -- back one word
map("i", "<A-Right>", "<C-o>w", opts) -- forward one word

if not vim.g.nvim_preview then
	for i = 1, 9 do
		map("n", "<leader>" .. i, "<Cmd>BufferGoto " .. i .. "<CR>", opts)
	end
	map("n", "<leader>0", "<Cmd>BufferPin<CR>", opts)

	local move_keys = { "!", "@", "#", "$", "%", "^", "&", "*", "(" }
	for i, key in ipairs(move_keys) do
		map("n", "<leader>" .. key, "<Cmd>BufferMove " .. i .. "<CR>", opts)
	end
end

local function is_diffview_open()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
		if ft == "DiffviewFiles" or ft == "DiffviewFileHistory" then
			return true
		end
	end
	return false
end

local function diffview_review()
	vim.cmd("DiffviewOpen")
end

local function diffview_file()
	vim.cmd("DiffviewOpen -- %")
	vim.cmd("DiffviewToggleFiles")
end

local function diffview_close()
	if is_diffview_open() then
		vim.cmd("DiffviewClose")
	end
end

map("n", "<leader>gr", diffview_review, { desc = "Diffview review" })
map("n", "<leader>df", diffview_file, { desc = "Diffview current file" })
map("n", "<leader>gc", diffview_close, { desc = "Diffview close" })

map("n", "<leader>Q", "<cmd>qa<CR>", {
	noremap = true,
	silent = true,
	desc = "Quit Neovim",
})

-- Yazi file manager
map({ "n", "v" }, "<leader>-", "<cmd>Yazi<cr>", { desc = "Open yazi at current file" })
map({ "n", "v" }, "<leader>e", "<cmd>Yazi<cr>", { desc = "Open yazi at current file" })
map("n", "<leader>E", "<cmd>Yazi cwd<cr>", { desc = "Open yazi in cwd" })
map("n", "<c-up>", "<cmd>Yazi toggle<cr>", { desc = "Resume last yazi session" })

-- Todo-comments
map("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find TODOs" })
map("n", "]t", function()
	require("todo-comments").jump_next()
end, { desc = "Next TODO" })
map("n", "[t", function()
	require("todo-comments").jump_prev()
end, { desc = "Previous TODO" })

-- Copy the full nvim-notify history to the clipboard
map("n", "<leader>..", function()
	local ok, notify = pcall(require, "notify")
	if not ok then
		vim.notify("nvim-notify is not available", vim.log.levels.WARN)
		return
	end

	local lines = {}
	for _, entry in ipairs(notify.history()) do
		local header = string.format("[%s] %s", entry.level, entry.title[1] ~= "" and entry.title[1] or "notify")
		table.insert(lines, header)
		vim.list_extend(lines, entry.message)
		table.insert(lines, "")
	end

	if #lines == 0 then
		vim.notify("No notifications to copy", vim.log.levels.INFO)
		return
	end

	local text = table.concat(lines, "\n")
	vim.fn.setreg("+", text)
	vim.fn.setreg('"', text)
	vim.notify(string.format("Copied %d notifications", #notify.history()), vim.log.levels.INFO)
end, { desc = "Copy all notifications to clipboard" })
