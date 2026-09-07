-- Persist only per-tab Explorer visibility; restored buffers determine roots and revealed files.
local M = {}

local pending

function M.capture()
	local tabs = vim.api.nvim_list_tabpages()
	local tab_states = require("ui.explorer_controller").session_state(tabs)
	-- Snacks keeps tree details at runtime; the session records visibility only.
	return { tabs = tab_states }
end

function M.stage(state)
	-- Older sessions have no Explorer payload, and malformed extras must not break restoration.
	pending = type(state) == "table" and state or nil
end

function M.restore(on_restored)
	local saved = pending
	pending = nil
	if type(saved) ~= "table" or type(saved.tabs) ~= "table" then
		if on_restored then
			on_restored()
		end
		return
	end
	local states = saved.tabs

	local original_tab = vim.api.nvim_get_current_tabpage()
	local original_win = vim.api.nvim_get_current_win()
	local tabs = vim.api.nvim_list_tabpages()

	local function finish()
		-- Opening sidebars across tabs must not change where the restored session leaves the user.
		if vim.api.nvim_tabpage_is_valid(original_tab) then
			vim.api.nvim_set_current_tabpage(original_tab)
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		if on_restored then
			on_restored()
		end
	end

	local function restore_tab(index)
		if index > #states then
			finish()
			return
		end

		local state = states[index]
		local tabpage = tabs[index]
		if not tabpage or not state.open then
			restore_tab(index + 1)
			return
		end

		-- Snacks opens asynchronously, so wait before selecting the next saved tab.
		vim.api.nvim_set_current_tabpage(tabpage)
		require("ui.explorer_controller").restore(state, function()
			restore_tab(index + 1)
		end)
	end

	-- Session files recreate tabs in order; handles themselves intentionally do not survive restarts.
	restore_tab(1)
end

return M
