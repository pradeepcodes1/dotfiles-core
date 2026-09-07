-- Present ordinary buffers and the small Harpoon working set in one UI picker.
local M = {}

local function absolute_harpoon_path(value, root)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if vim.startswith(value, "/") then
		return vim.fs.normalize(value)
	end
	return vim.fs.normalize(vim.fs.joinpath(root, value))
end

local function harpoon_slot(path)
	local ok, harpoon = pcall(require, "harpoon")
	if not ok or path == "" then
		return nil
	end

	local list = harpoon:list()
	local root = list.config.get_root_dir()
	path = vim.fs.normalize(path)
	for index = 1, list:length() do
		local entry = list:get(index)
		if entry and absolute_harpoon_path(entry.value, root) == path then
			return index
		end
	end
end

function M.format(item, picker)
	local slot = item.harpoon_slot or harpoon_slot(item.file)
	local prefix = slot and ("[%d]"):format(slot) or "   "
	local formatted = { { prefix, slot and "SnacksPickerSpecial" or "SnacksPickerDelim" }, { " " } }
	-- Retain Snacks' buffer number, flags, filename, and modification indicators.
	vim.list_extend(formatted, Snacks.picker.format.buffer(item, picker))
	return formatted
end

function M.transform(item)
	local slot = harpoon_slot(item.file)
	-- Booleans sort marked buffers as one group; the numeric field orders that group by slot.
	item.harpooned = slot ~= nil
	item.harpoon_slot = slot
	return item
end

function M.show_relative_numbers(picker)
	local function apply()
		local win = picker.list and picker.list.win and picker.list.win.win
		if not win or not vim.api.nvim_win_is_valid(win) then
			return
		end
		vim.wo[win].number = true
		vim.wo[win].relativenumber = true
		vim.wo[win].numberwidth = 4
		-- An empty status column lets Neovim render its native relative numbers.
		vim.wo[win].statuscolumn = ""
	end

	-- Comfy clears numbers on nofile BufEnter, so the picker-local WinEnter hook runs afterward.
	picker.list.win:on("WinEnter", function()
		vim.schedule(apply)
	end)
	vim.schedule(apply)
end

function M.open()
	-- The core buffer mappings can run before Harpoon's own lazy-loading keys.
	require("lazy").load({ plugins = { "harpoon" } })
	Snacks.picker.buffers()
end

return M
