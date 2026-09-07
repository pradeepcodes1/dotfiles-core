-- Persist source breakpoints using the integration documented by AutoSession.
local M = {}

local pending

local function breakpoint_api()
	local ok, breakpoints = pcall(require, "dap.breakpoints")
	return ok and breakpoints or nil
end

function M.capture()
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

function M.stage(state)
	-- Treat absent or malformed data as an empty set to prevent cross-project leakage.
	pending = type(state) == "table" and state or {}
end

function M.restore(on_restored)
	local state = pending or {}
	pending = nil
	local breakpoints = breakpoint_api()
	if not breakpoints then
		if on_restored then
			on_restored()
		end
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
	if on_restored then
		on_restored()
	end
end

return M
