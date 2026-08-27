-- show quickfix results in the same focused floating workflow as other result lists.
local M = {}

local FLOAT_MODE = "qflist_float"
local trouble_float = require("core.trouble_float")

local function has_items()
	return vim.fn.getqflist({ size = 0 }).size > 0
end

function M.open_float()
	if not has_items() then
		vim.notify("Quickfix list is empty", vim.log.levels.INFO)
		return false
	end

	trouble_float.focus_first_item(trouble_float.get(true).open(FLOAT_MODE))
	return true
end

function M.toggle_float()
	if has_items() then
		local trouble = trouble_float.get(true)
		local was_open = trouble.is_open(FLOAT_MODE)
		local view = trouble.toggle(FLOAT_MODE)
		if not was_open then
			trouble_float.focus_first_item(view)
		end
		return
	end

	vim.notify("Quickfix list is empty", vim.log.levels.INFO)
end

function M.close()
	vim.cmd("cclose")

	local trouble = trouble_float.get(false)
	if not trouble or not trouble.is_open(FLOAT_MODE) then
		return
	end

	trouble.close(FLOAT_MODE)
end

vim.api.nvim_create_user_command("QuickfixFloat", M.toggle_float, {
	desc = "Toggle floating quickfix list",
})

return M
