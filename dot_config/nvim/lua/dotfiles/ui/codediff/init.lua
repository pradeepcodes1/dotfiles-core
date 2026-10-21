local M = {}

local function navigate_file(direction)
	return function()
		local lifecycle = require("codediff.ui.lifecycle")
		local tab = vim.api.nvim_get_current_tabpage()
		local panel = lifecycle.get_panel(tab)
		local win = panel and panel.view and panel.view.winid
		local navigate = require("codediff")[direction .. "_file"]
		-- CodeDiff temporarily focuses the tree; use that stable window as its return target.
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_call(win, navigate)
		else
			navigate()
		end
		-- File selection can replace diff windows, so resolve the editor again after it finishes.
		vim.schedule(function()
			if vim.api.nvim_get_current_tabpage() ~= tab then
				return
			end
			local session = lifecycle.get_session(tab)
			local editor = session and session.modified_win
			if editor and vim.api.nvim_win_is_valid(editor) then
				vim.api.nvim_set_current_win(editor)
			end
		end)
	end
end

local function hunk_action(action)
	return function()
		-- Resolve CodeDiff's current buffer callback so file switches retain its checks and confirmations.
		local mapping = vim.fn.maparg("<Plug>(CodeDiff-" .. action .. ")", "n", false, true)
		if mapping.callback then
			mapping.callback()
		else
			vim.notify("Focus a diff editor pane to " .. action .. " a hunk", vim.log.levels.INFO)
		end
	end
end

function M.toggle_layout()
	local lifecycle = require("codediff.ui.lifecycle")
	local tab = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tab)
	if not session then
		vim.notify("Open a CodeDiff view before changing its layout", vim.log.levels.INFO)
		return
	end
	if session.result_win then
		vim.notify("Merge views require the side-by-side layout", vim.log.levels.INFO)
		return
	end

	require("codediff.ui.view").toggle_layout(tab)
	local updated = lifecycle.get_session(tab)
	if updated then
		-- Remember this tab's explicit choice so resize and TabEnter hooks preserve it.
		vim.api.nvim_tabpage_set_var(tab, "codediff_layout", updated.layout)
	end
end

-- The <leader>h mode's heads inside a diff tab, beside the navigation actions
-- they drive. ui/modal.lua adds q and draws the hint.
local function heads()
	local function navigate_hunks_across_files(direction)
		return function()
			local config = require("codediff.config")
			local previous = config.options.diff.cycle_hunks_across_files
			-- Plain hunk navigation forms one continuous review stream across changed files.
			config.options.diff.cycle_hunks_across_files = true
			require("codediff")[direction .. "_hunk"]()
			config.options.diff.cycle_hunks_across_files = previous
		end
	end

	local function page_files(direction)
		return function()
			local panel = require("codediff.ui.lifecycle").get_panel(vim.api.nvim_get_current_tabpage())
			local explorer = panel and panel.name == "explorer" and panel.view
			local height = explorer
					and explorer.winid
					and vim.api.nvim_win_is_valid(explorer.winid)
					and vim.api.nvim_win_get_height(explorer.winid)
				or 2
			local navigate = navigate_file(direction == "up" and "prev" or "next")

			-- Match picker page movement by advancing half the visible explorer rows.
			for _ = 1, math.max(1, math.floor(height / 2)) do
				navigate()
			end
		end
	end

	return {
		{ "j", navigate_hunks_across_files("next"), desc = "Next hunk across files" },
		{ "k", navigate_hunks_across_files("prev"), desc = "Previous hunk across files" },
		{ "<C-j>", navigate_file("next"), desc = "Next file / history commit" },
		{ "<C-k>", navigate_file("prev"), desc = "Previous file / history commit" },
		{ "<C-Down>", page_files("down"), desc = "Next explorer page" },
		{ "<C-Up>", page_files("up"), desc = "Previous explorer page" },
		{ "t", M.toggle_layout, desc = "Toggle one/two pane layout" },
		{ "s", hunk_action("stage"), desc = "Stage hunk" },
		{ "u", hunk_action("unstage"), desc = "Unstage hunk" },
		{ "r", hunk_action("discard"), desc = "Discard hunk" },
	}
end

-- A which-key mode replaces the Hydra; the loop ends with its prompt, so no
-- TabLeave handler is needed to release the keys.
local mode = require("dotfiles.ui.modal").new("<F34>", "CodeDiff", heads)

function M.activate()
	if vim.t.codediff_view then
		mode()
	end
end

return M
