-- show the dashboard without leaving the tabline behind when a buffer replaces it.
local M = {}

function M.show()
	if not (Snacks and Snacks.dashboard) then
		return
	end

	-- Snacks hides the tabline for the dashboard; nothing restores it once a
	-- real buffer takes over, so remember the value and put it back.
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

return M
