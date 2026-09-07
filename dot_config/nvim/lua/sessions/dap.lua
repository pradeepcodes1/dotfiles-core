-- Persist debugger breakpoints and presentation as one session-owned payload.
local M = {}

local pending

local function breakpoint_api()
	local ok, breakpoints = pcall(require, "dap.breakpoints")
	return ok and breakpoints or nil
end

local function watches_api()
	local ok, dapui = pcall(require, "dapui")
	return ok and dapui.elements and dapui.elements.watches or nil
end

local function capture_breakpoints()
	local breakpoints = breakpoint_api()
	local saved = {}
	if not breakpoints then
		return { files = saved }
	end

	for bufnr, entries in pairs(breakpoints.get()) do
		local filename = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or ""
		if filename ~= "" then
			saved[filename] = {}
			for _, breakpoint in ipairs(entries) do
				-- Adapter verification IDs are transient; only user-authored breakpoint fields survive.
				saved[filename][#saved[filename] + 1] = {
					line = breakpoint.line,
					condition = breakpoint.condition,
					hit_condition = breakpoint.hitCondition,
					log_message = breakpoint.logMessage,
				}
			end
		end
	end
	return { files = saved }
end

local function capture_ui()
	local state = require("ui.dap").session_state()
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

local function restore_breakpoints(state)
	local breakpoints = breakpoint_api()
	if not breakpoints then
		return
	end

	breakpoints.clear()
	for filename, entries in pairs(type(state.files) == "table" and state.files or {}) do
		if type(filename) == "string" and vim.fn.filereadable(filename) == 1 and type(entries) == "table" then
			local bufnr = vim.fn.bufadd(filename)
			vim.fn.bufload(bufnr)
			for _, breakpoint in ipairs(entries) do
				if type(breakpoint) == "table" and type(breakpoint.line) == "number" and breakpoint.line > 0 then
					breakpoints.set({
						condition = breakpoint.condition,
						hit_condition = breakpoint.hit_condition,
						log_message = breakpoint.log_message,
					}, bufnr, breakpoint.line)
				end
			end
		end
	end
end

local function restore_ui(state)
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

	require("ui.dap").restore(state)
end

function M.capture()
	return {
		breakpoints = capture_breakpoints(),
		ui = capture_ui(),
	}
end

function M.stage(state)
	-- Treat absent or malformed data as empty so debugger state cannot leak between projects.
	pending = type(state) == "table" and state or {}
end

function M.restore(on_restored)
	local state = pending or {}
	pending = nil
	restore_breakpoints(type(state.breakpoints) == "table" and state.breakpoints or {})
	restore_ui(type(state.ui) == "table" and state.ui or {})
	if on_restored then
		on_restored()
	end
end

return M
