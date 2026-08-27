-- hide duplicate virtual text while the same diagnostic is readable in a line float.
local M = {}

local suppressed_lines = {}
local active_float_by_win = {}

local function get_line_counts(bufnr)
	return suppressed_lines[bufnr]
end

local function is_suppressed(bufnr, lnum)
	local line_counts = get_line_counts(bufnr)
	return line_counts ~= nil and (line_counts[lnum] or 0) > 0
end

local function increment_suppression(bufnr, lnum)
	local line_counts = suppressed_lines[bufnr]
	if not line_counts then
		line_counts = {}
		suppressed_lines[bufnr] = line_counts
	end

	line_counts[lnum] = (line_counts[lnum] or 0) + 1
end

local function decrement_suppression(bufnr, lnum)
	local line_counts = suppressed_lines[bufnr]
	if not line_counts or not line_counts[lnum] then
		return
	end

	local next_count = line_counts[lnum] - 1
	if next_count > 0 then
		line_counts[lnum] = next_count
		return
	end

	line_counts[lnum] = nil
	if next(line_counts) == nil then
		suppressed_lines[bufnr] = nil
	end
end

local function redraw_diagnostics(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
		vim.diagnostic.show(nil, bufnr)
	end
end

local function filter_diagnostics(bufnr, diagnostics)
	local line_counts = get_line_counts(bufnr)
	if not line_counts or vim.tbl_isempty(line_counts) then
		return diagnostics
	end

	return vim.tbl_filter(function(diagnostic)
		return not is_suppressed(bufnr, diagnostic.lnum)
	end, diagnostics)
end

local function install_virtual_text_wrapper()
	local current_handler = vim.diagnostic.handlers.virtual_text
	if current_handler._suppress_current_line_wrapper then
		return
	end

	local wrapped_handler = {
		_suppress_current_line_wrapper = true,
		_original = current_handler,
		show = function(namespace, bufnr, diagnostics, opts)
			current_handler.show(namespace, bufnr, filter_diagnostics(bufnr, diagnostics), opts)
		end,
	}

	if current_handler.hide then
		wrapped_handler.hide = function(namespace, bufnr)
			current_handler.hide(namespace, bufnr)
		end
	end

	setmetatable(wrapped_handler, { __index = current_handler })
	vim.diagnostic.handlers.virtual_text = wrapped_handler
end

local function attach_float_cleanup(winid, bufnr, lnum)
	active_float_by_win[winid] = {
		bufnr = bufnr,
		lnum = lnum,
	}

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(winid),
		once = true,
		callback = function()
			local float_state = active_float_by_win[winid]
			active_float_by_win[winid] = nil
			if not float_state then
				return
			end

			decrement_suppression(float_state.bufnr, float_state.lnum)
			redraw_diagnostics(float_state.bufnr)
		end,
	})
end

function M.open_line_float()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
	local diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })

	if #diagnostics == 0 then
		return vim.diagnostic.open_float({ scope = "line" })
	end

	increment_suppression(bufnr, lnum)
	redraw_diagnostics(bufnr)

	local float_bufnr, winid = vim.diagnostic.open_float({ scope = "line" })
	if not winid then
		decrement_suppression(bufnr, lnum)
		redraw_diagnostics(bufnr)
		return float_bufnr, winid
	end

	local existing_float = active_float_by_win[winid]
	if existing_float then
		decrement_suppression(bufnr, lnum)
		if existing_float.bufnr ~= bufnr or existing_float.lnum ~= lnum then
			redraw_diagnostics(bufnr)
		end
		return float_bufnr, winid
	end

	attach_float_cleanup(winid, bufnr, lnum)
	return float_bufnr, winid
end

install_virtual_text_wrapper()

return M
