local M = {}
local path_util = require("core.path")
local project_paths = require("project.paths")

--- Collapse the layout down to one window. Floats go first, since `:only`
--- leaves them behind; then the other tab pages, then the other windows. The
--- panels with teardown of their own (explorer, aerial, dapui, neotest) are
--- closed by the caller before this runs, so they are not merely hidden.
local function close_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	-- `:only` keeps whichever window is current, so pressing this from a scratch
	-- pane -- the info split, a leftover panel -- would make that pane the one
	-- survivor. Hand it a real file window to keep instead.
	if vim.bo.buftype ~= "" then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	end

	-- Silent because both are informational when there is nothing to close
	-- ("Already only one window"), and this runs off a key press.
	vim.cmd("silent! tabonly")
	vim.cmd("silent! only")
end

function M.contains(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	if path:match("^%w+://") then
		if not vim.startswith(path, "file://") then
			return false
		end
		local ok, filename = pcall(vim.uri_to_fname, path)
		if not ok then
			return false
		end
		path = filename
	end

	return path_util.under(path_util.normalize(path), project_paths.current_root())
end
--- Back to what a freshly restored project looks like: one window, no buffers,
--- the file picker open. The session on disk is left alone, so this is a clean
--- slate to work from and not a discard. Modified buffers stay -- nothing here
--- is worth losing an edit over -- and so does anything outside the root, which
--- is why the layout is collapsed before the wipe rather than after: a window
--- left showing a kept buffer is the point.
function M.reset()
	local root = project_paths.current_root()
	if not root then
		return false
	end

	close_windows()

	local kept = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].buflisted and M.contains(vim.api.nvim_buf_get_name(buf)) then
			if vim.bo[buf].modified then
				kept = kept + 1
			else
				pcall(vim.api.nvim_buf_delete, buf, {})
			end
		end
	end

	if kept > 0 then
		vim.notify(("Kept %d modified buffer%s"):format(kept, kept == 1 and "" or "s"), vim.log.levels.WARN)
	end

	Snacks.picker.files({ cwd = root })
	return true
end

return M
