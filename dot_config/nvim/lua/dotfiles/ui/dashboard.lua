-- Keep dashboard behavior behind one focused UI module.
local M = {}

function M.show()
	if not (Snacks and Snacks.dashboard) then
		return
	end

	-- Snacks hides the tabline for the dashboard; nothing restores it once a
	-- real buffer takes over, so remember the value and put it back.
	local saved_tabline = vim.o.showtabline
	Snacks.dashboard()
	-- Cleared group, not just `once`: show() may run again before any BufEnter,
	-- and a second pending handler would restore a stale showtabline.
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("dashboard_tabline_restore", { clear = true }),
		once = true,
		desc = "Restore showtabline once a real buffer replaces the dashboard",
		callback = function()
			if vim.bo.filetype ~= "snacks_dashboard" then
				vim.o.showtabline = saved_tabline
			end
		end,
	})
end

return M
