-- Keep auto-session's single custom-data slot extensible for independent layout owners.
local M = {}

local owners = {
	{ name = "dap", module = "sessions.dap" },
	{ name = "explorer", module = "sessions.explorer" },
	-- Rebuild diff tabs after ordinary tabs and their sidebars have been restored.
	{ name = "codediff", module = "sessions.codediff" },
}

function M.capture()
	local state = {}
	for _, owner in ipairs(owners) do
		state[owner.name] = require(owner.module).capture()
	end
	return vim.json.encode(state)
end

function M.stage(extra_data)
	local ok, state = pcall(vim.json.decode, extra_data)
	if not ok or type(state) ~= "table" then
		return
	end

	for _, owner in ipairs(owners) do
		-- Every owner sees missing data so switching from an older session clears global plugin state.
		require(owner.module).stage(state[owner.name])
	end
end

function M.restore()
	local function restore_owner(index)
		local owner = owners[index]
		if not owner then
			return
		end

		-- Wait for asynchronous owners before another one is allowed to change the active tab.
		require(owner.module).restore(function()
			restore_owner(index + 1)
		end)
	end

	restore_owner(1)
end

return M
