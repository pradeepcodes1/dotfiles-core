-- CodeDiff supplies repository review, file diffs, and line history through one lazy command.
local function preferred_layout()
	-- Leave enough room for two readable code panes and the file explorer.
	return vim.o.columns < 180 and "inline" or "side-by-side"
end

local function adjust_layout()
	if not package.loaded.codediff then
		return
	end
	local layout = preferred_layout()
	require("codediff").setup({ diff = { layout = layout } })
	-- CodeDiff's own toggle preserves the session; merge views cannot use inline mode.
	local lifecycle = require("codediff.ui.lifecycle")
	local tab = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tab)
	if session and not session.result_win and session.layout ~= layout then
		require("codediff.ui.view").toggle_layout(tab)
	end
end

return {
	"esmuellert/codediff.nvim",
	cmd = "CodeDiff",
	-- Diff buffers need the navigation Hydra even when Gitsigns has not attached.
	dependencies = { "nvimtools/hydra.nvim" },
	opts = function()
		return {
			diff = { layout = preferred_layout() },
			-- Start reviewing the modified code immediately instead of focusing the navigation panel.
			explorer = { initial_focus = "modified" },
			history = { initial_focus = "modified" },
			-- Hydra invokes these callbacks without longer leader-h mappings delaying its entry.
			keymaps = {
				view = {
					-- Reserve q for leaving Hydra; closing the diff stays on leader-gc.
					quit = false,
					stage_hunk = "<Plug>(CodeDiffHydra-stage)",
					unstage_hunk = "<Plug>(CodeDiffHydra-unstage)",
					discard_hunk = "<Plug>(CodeDiffHydra-discard)",
				},
			},
		}
	end,
	init = function()
		-- Match the Git-hunk prefix in read-only revision buffers and explorer panes too.
		require("core.keymaps").codediff_navigation()
		local group = vim.api.nvim_create_augroup("ProjectCodeDiffTabs", { clear = true })
		-- Recheck hidden diff tabs when revisited, as well as the visible tab after resizing.
		vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
			group = group,
			callback = function()
				vim.schedule(adjust_layout)
			end,
		})
		-- Lifecycle events make the close shortcut safe in ordinary tabs.
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "CodeDiffOpen",
			callback = function(event)
				vim.api.nvim_tabpage_set_var(event.data.tabpage, "codediff_view", true)
				-- Whole-repository reviews share one tab; file views identify the code being compared.
				local tab = event.data.tabpage
				local mode = event.data.mode
				vim.api.nvim_tabpage_set_var(tab, "codediff_mode", mode)
				local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
				vim.api.nvim_tabpage_set_var(
					tab,
					"tabname",
					mode == "explorer" and "DiffWhole" or mode == "history" and "File History" or "d " .. filename
				)
				if mode == "explorer" then
					for _, other in ipairs(vim.api.nvim_list_tabpages()) do
						if other ~= tab and vim.t[other].codediff_mode == "explorer" then
							-- Defer cleanup until CodeDiff has finished registering the new session.
							vim.schedule(function()
								if vim.api.nvim_tabpage_is_valid(other) and vim.api.nvim_tabpage_is_valid(tab) then
									require("codediff.ui.lifecycle").close(tab)
									vim.api.nvim_set_current_tabpage(other)
								end
							end)
							break
						end
					end
				end
			end,
		})
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "CodeDiffClose",
			callback = function(event)
				if vim.api.nvim_tabpage_is_valid(event.data.tabpage) then
					vim.api.nvim_tabpage_set_var(event.data.tabpage, "codediff_view", false)
					-- Clear ownership together with the title when a view closes.
					pcall(vim.api.nvim_tabpage_del_var, event.data.tabpage, "codediff_mode")
					pcall(vim.api.nvim_tabpage_del_var, event.data.tabpage, "tabname")
				end
			end,
		})
	end,
}
