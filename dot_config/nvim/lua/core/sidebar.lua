-- make Explorer and Symbols behave as one sidebar with shared focus and cleanup.
local M = {}

local close_guard = vim.api.nvim_create_augroup("explorer_symbols_sidebar_guard", { clear = true })
local group_open = false

local function is_sidebar_window(win)
	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype

	return ft == "aerial" or (ft == "neo-tree" and vim.b[buf].neo_tree_source == "filesystem")
end

local function sidebar_windows()
	local wins = {}

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if is_sidebar_window(win) then
			table.insert(wins, win)
		end
	end

	return wins
end

local function arm_close_guard(attempt)
	if not group_open then
		return
	end

	local wins = sidebar_windows()
	if #wins < 2 then
		if attempt < 50 then
			vim.defer_fn(function()
				arm_close_guard(attempt + 1)
			end, 20)
		end
		return
	end

	vim.api.nvim_clear_autocmds({ group = close_guard, event = "WinClosed" })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = close_guard,
		pattern = vim.tbl_map(tostring, wins),
		desc = "Keep Explorer and Symbols sidebar panes together",
		callback = function()
			vim.schedule(function()
				if not group_open then
					return
				end

				local remaining = sidebar_windows()
				if #remaining == 1 then
					M.close()
				elseif #remaining >= 2 then
					arm_close_guard(0)
				end
			end)
		end,
	})
end

function M.is_open()
	return #sidebar_windows() > 0
end

function M.open()
	if vim.g.nvim_preview then
		return
	end
	group_open = true
	-- Show Neo-tree without stealing focus so Aerial opens against the source
	-- buffer instead of trying to attach to the explorer.
	require("core.neotree_explorer").show()
	vim.cmd("AerialOpen")
	arm_close_guard(0)
end

function M.close()
	group_open = false
	vim.api.nvim_clear_autocmds({ group = close_guard, event = "WinClosed" })
	require("core.neotree_explorer").forget()
	require("aerial").close_all()
	require("neo-tree.command").execute({
		action = "close",
		source = "filesystem",
		position = "left",
	})
end

function M.toggle()
	if vim.g.nvim_preview then
		return
	end
	if M.is_open() then
		M.close()
	else
		M.open()
	end
end

return M
