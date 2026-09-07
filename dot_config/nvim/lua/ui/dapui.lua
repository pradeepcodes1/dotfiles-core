-- Keep DAP's dedicated tab lifecycle with the other user-interface controllers.
local M = {}

local debug_tab
local return_tab
local session_open = false
local suspended_focus

local function debug_tab_is_open()
	return debug_tab and vim.api.nvim_tabpage_is_valid(debug_tab)
end

function M.open()
	session_open = true
	if debug_tab_is_open() then
		vim.api.nvim_set_current_tabpage(debug_tab)
		require("dapui").open()
		return
	end

	return_tab = vim.api.nvim_get_current_tabpage()
	local source_buf = vim.api.nvim_get_current_buf()

	-- Reuse the current source buffer in a new tab instead of creating a stray empty buffer.
	vim.cmd("tab sbuffer " .. source_buf)
	debug_tab = vim.api.nvim_get_current_tabpage()
	vim.t.dapui_debug_tab = true
	require("dapui").open()
end

function M.close()
	session_open = false
	if not debug_tab_is_open() then
		debug_tab = nil
		return_tab = nil
		require("dapui").close()
		return
	end

	require("dapui").close()
	local tab_number = vim.api.nvim_tabpage_get_number(debug_tab)
	vim.cmd(tab_number .. "tabclose")
	debug_tab = nil

	if return_tab and vim.api.nvim_tabpage_is_valid(return_tab) then
		vim.api.nvim_set_current_tabpage(return_tab)
	end
	return_tab = nil
end

function M.session_state()
	-- Track intent separately because AutoSession removes utility windows before saving.
	return { open = session_open }
end

function M.suspend_for_save()
	if not debug_tab_is_open() then
		return
	end

	suspended_focus = {
		tab = vim.api.nvim_get_current_tabpage(),
		win = vim.api.nvim_get_current_win(),
		was_debug_tab = vim.api.nvim_get_current_tabpage() == debug_tab,
	}
	-- Keep the dedicated debugger tab out of the native session; custom data recreates it once.
	require("dapui").close()
	local tab_number = vim.api.nvim_tabpage_get_number(debug_tab)
	vim.cmd(tab_number .. "tabclose")
	debug_tab = nil
end

function M.resume_after_save()
	local focus = suspended_focus
	suspended_focus = nil
	if not focus or not session_open or vim.v.exiting ~= vim.NIL then
		return
	end

	M.open()
	-- A manual save should not move the user unless they were working in the debugger tab.
	if not focus.was_debug_tab and vim.api.nvim_tabpage_is_valid(focus.tab) then
		vim.api.nvim_set_current_tabpage(focus.tab)
		if vim.api.nvim_win_is_valid(focus.win) then
			vim.api.nvim_set_current_win(focus.win)
		end
	end
end

function M.restore(state)
	-- Restored sessions only recreate UI visibility; a live debug process cannot survive Neovim.
	if type(state) == "table" and state.open then
		M.open()
	else
		M.close()
	end
end

function M.toggle()
	if debug_tab_is_open() then
		M.close()
	else
		M.open()
	end
end

return M
