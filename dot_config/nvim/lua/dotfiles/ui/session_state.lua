-- Keep auto-session's single custom-data slot extensible for independent layout owners.
local M = {}

local owners = {
	{ name = "dap", module = "dotfiles.ui.dap.session" },
	{ name = "explorer", module = "dotfiles.ui.explorer.session" },
	-- Rebuild diff tabs after ordinary tabs and their sidebars have been restored.
	{ name = "codediff", module = "dotfiles.ui.codediff.session" },
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

--- Owner-managed tabs are removed before mksession runs, so the native snapshot
--- holds only ordinary windows and the companion data recreates the rest. Owners
--- with no transient tabs simply define neither hook.
function M.suspend_for_save()
	for _, owner in ipairs(owners) do
		local module = require(owner.module)
		if module.suspend_for_save then
			module.suspend_for_save()
		end
	end
end

--- Manual saves put the live UI back once the snapshot is complete; an exit
--- leaves that work to the next restore.
function M.resume_after_save()
	for _, owner in ipairs(owners) do
		local module = require(owner.module)
		if module.resume_after_save then
			module.resume_after_save()
		end
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
