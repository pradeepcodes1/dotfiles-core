local M = {}
local hydra

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
		local mapping = vim.fn.maparg("<Plug>(CodeDiffHydra-" .. action .. ")", "n", false, true)
		if mapping.callback then
			mapping.callback()
		else
			vim.notify("Focus a diff editor pane to " .. action .. " a hunk", vim.log.levels.INFO)
		end
	end
end

function M.activate()
	if not vim.t.codediff_view then
		return
	end
	-- One global Hydra survives file and pane switches inside the diff session.
	if not hydra then
		local diff = require("codediff")
		hydra = require("hydra")({
			name = "CodeDiff",
			mode = "n",
			config = {
				color = "pink",
				-- Keep diff navigation focused until the optional help is requested.
				hint = { float_opts = { border = "rounded" }, hide_on_load = true },
			},
			hint = [[
 CodeDiff
 _j_: next hunk across files  _k_: previous hunk across files
 _<C-j>_: next file  _<C-k>_: previous file
 _<C-Down>_: next page  _<C-Up>_: previous page
 _s_: stage  _u_: unstage  _r_: discard
 _q_/_<Esc>_: exit
]],
			-- Runtime actions plug into modal bindings declared in the central file.
			heads = require("core.keymaps").codediff_hydra_heads(diff, navigate_file, hunk_action),
		})
		-- Leaving a diff tab must release navigation keys back to the editor.
		vim.api.nvim_create_autocmd("TabLeave", {
			group = vim.api.nvim_create_augroup("codediff_hydra_exit", { clear = true }),
			desc = "Release CodeDiff hydra keys when leaving a diff tab",
			callback = function()
				-- Global event: only a diff tab owns these keys, per M.activate above.
				if vim.t.codediff_view then
					hydra:exit()
				end
			end,
		})
	end
	hydra:activate()
end

return M
