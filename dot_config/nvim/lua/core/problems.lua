-- keep workspace and buffer diagnostics behind one consistent Trouble interface.
local M = {}

local trouble_float = require("core.trouble_float")
local methods = vim.lsp.protocol.Methods or {}
local workspace_diagnostic_method = methods.workspace_diagnostic or "workspace/diagnostic"
local WORKSPACE_FLOAT_MODE = "diagnostics_float"
local BUFFER_FLOAT_MODE = "diagnostics_buffer_float"

local function workspace_clients()
	local clients = vim.lsp.get_clients({ bufnr = 0, method = workspace_diagnostic_method })
	if #clients > 0 then
		return clients
	end

	return vim.lsp.get_clients({ method = workspace_diagnostic_method })
end

function M.refresh_workspace()
	local clients = workspace_clients()
	for _, client in ipairs(clients) do
		vim.lsp.buf.workspace_diagnostics({ client_id = client.id })
	end

	return #clients > 0
end

function M.toggle_workspace()
	M.refresh_workspace()
	trouble_float.get(true).toggle("diagnostics")
end

function M.toggle_buffer()
	trouble_float.get(true).toggle({
		mode = "diagnostics",
		filter = { buf = 0 },
	})
end

function M.toggle_workspace_float()
	M.refresh_workspace()
	local trouble = trouble_float.get(true)
	local was_open = trouble.is_open(WORKSPACE_FLOAT_MODE)
	local view = trouble.toggle(WORKSPACE_FLOAT_MODE)
	if not was_open then
		trouble_float.focus_first_item(view)
	end
end

function M.toggle_buffer_float()
	local trouble = trouble_float.get(true)
	local was_open = trouble.is_open(BUFFER_FLOAT_MODE)
	local view = trouble.toggle(BUFFER_FLOAT_MODE)
	if not was_open then
		trouble_float.focus_first_item(view)
	end
end

function M.close()
	local trouble = trouble_float.get(false)
	if not trouble then
		return
	end

	while trouble.close() do
	end
end

vim.api.nvim_create_user_command("Problems", M.toggle_workspace, {
	desc = "Toggle workspace Problems",
})

vim.api.nvim_create_user_command("ProblemsBuffer", M.toggle_buffer, {
	desc = "Toggle buffer Problems",
})

vim.api.nvim_create_user_command("ProblemsFloat", M.toggle_workspace_float, {
	desc = "Toggle floating workspace Problems",
})

vim.api.nvim_create_user_command("ProblemsBufferFloat", M.toggle_buffer_float, {
	desc = "Toggle floating buffer Problems",
})

vim.api.nvim_create_user_command("ProblemsRefresh", function()
	M.refresh_workspace()
end, {
	desc = "Refresh workspace diagnostics",
})

return M
