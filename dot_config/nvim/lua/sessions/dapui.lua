-- Persist debugger presentation state that nvim-dap-ui exposes as stable public APIs.
local M = {}

local pending

local function watches_api()
	local ok, dapui = pcall(require, "dapui")
	return ok and dapui.elements and dapui.elements.watches or nil
end

function M.capture()
	local state = require("ui.dapui").session_state()
	state.watches = {}

	local watches = watches_api()
	if not watches then
		return state
	end
	for _, watch in ipairs(watches.get()) do
		-- Copy only documented fields so evaluation results never enter the session file.
		state.watches[#state.watches + 1] = {
			expression = watch.expression,
			expanded = watch.expanded == true,
		}
	end
	return state
end

function M.stage(state)
	-- A missing payload represents an older session and should clear state from the previous project.
	pending = type(state) == "table" and state or {}
end

function M.restore(on_restored)
	local state = pending or {}
	pending = nil
	local watches = watches_api()
	if watches then
		-- Watch expressions are global to dap-ui, so replace rather than merge across projects.
		for index = #watches.get(), 1, -1 do
			watches.remove(index)
		end
		for _, watch in ipairs(type(state.watches) == "table" and state.watches or {}) do
			if type(watch.expression) == "string" and watch.expression ~= "" then
				watches.add(watch.expression)
				if watch.expanded then
					watches.toggle_expand(#watches.get())
				end
			end
		end
	end

	require("ui.dapui").restore(state)
	if on_restored then
		on_restored()
	end
end

return M
