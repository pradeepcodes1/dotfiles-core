-- Recreate diff views through commands instead of restoring stale virtual buffers and window IDs.
local M = {}
local pending
local suspended

local function lifecycle()
	return package.loaded["codediff.ui.lifecycle"]
end

function M.capture()
	if suspended then
		return suspended.state
	end
	local state = { views = {} }
	local api = lifecycle()
	if not api then
		return state
	end
	for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local session = api.get_session(tab)
		if session and not session.merge then
			local panel = session.panel
			local mode = panel and panel.name or "standalone"
			local opts = panel and panel.view and panel.view.opts or {}
			local file = session.modified and session.modified.absolute
			if mode == "history" then
				file = opts.file_path
			end
			local args = {}
			if mode == "history" then
				args = { "history" }
				if opts.range and opts.range ~= "" then
					table.insert(args, opts.range)
				end
				if file and file ~= "" then
					table.insert(args, "%")
				end
			elseif mode == "standalone" then
				args = { "file", session.original_revision or "HEAD" }
				-- WORKING is an internal sentinel; omitting the second revision selects the working tree.
				if session.modified_revision and session.modified_revision ~= "WORKING" then
					table.insert(args, session.modified_revision)
				end
			else
				file = nil
				-- Preserve staged and explicit revision reviews instead of reopening them as working-tree changes.
				if session.modified_revision == "STAGED" then
					args = { "--staged" }
				end
				if session.original_revision and session.original_revision ~= "STAGED" then
					table.insert(args, session.original_revision)
				end
				if
					session.modified_revision
					and session.modified_revision ~= "WORKING"
					and session.modified_revision ~= "STAGED"
				then
					table.insert(args, session.modified_revision)
				end
			end
			if file and session.git_root and not vim.startswith(file, "/") then
				file = vim.fs.joinpath(session.git_root, file)
			end
			table.insert(state.views, {
				mode = mode,
				args = args,
				file = file,
				root = session.git_root,
				position = index,
				range = opts.line_range,
				active = tab == vim.api.nvim_get_current_tabpage(),
			})
		end
	end
	return state
end

function M.stage(state)
	-- Older sessions have no diff views, so never carry a previous project's list forward.
	pending = type(state) == "table" and state or {}
end

local function reopen(state, done)
	local views = type(state.views) == "table" and state.views or {}
	local original = vim.api.nvim_get_current_tabpage()
	local active
	local function next_view(index)
		local view = views[index]
		if not view then
			local target = active or original
			if vim.api.nvim_tabpage_is_valid(target) then
				vim.api.nvim_set_current_tabpage(target)
			end
			if done then
				done()
			end
			return
		end
		if
			type(view.root) ~= "string"
			or vim.fn.isdirectory(view.root) ~= 1
			or (view.file and vim.fn.filereadable(view.file) ~= 1)
		then
			next_view(index + 1)
			return
		end
		-- A temporary launch tab keeps file arguments and cwd changes out of ordinary editor tabs.
		vim.cmd.tabnew()
		local launch = vim.api.nvim_get_current_tabpage()
		vim.cmd({ cmd = "tcd", args = { view.root }, mods = { noautocmd = true } })
		if view.file then
			vim.cmd.edit(vim.fn.fnameescape(view.file))
		end
		local command = { cmd = "CodeDiff", args = view.args or {} }
		if type(view.range) == "table" then
			command.range = { view.range.start_line, view.range.end_line }
		end
		local ok, err = pcall(vim.cmd, command)
		local attempts = 0
		local function await_view()
			attempts = attempts + 1
			local tab = vim.api.nvim_get_current_tabpage()
			local ready = tab ~= launch and lifecycle() and lifecycle().get_session(tab)
			if ok and not ready and attempts < 100 then
				vim.defer_fn(await_view, 50)
				return
			end
			if vim.api.nvim_tabpage_is_valid(launch) then
				vim.cmd(vim.api.nvim_tabpage_get_number(launch) .. "tabclose")
			end
			if ready then
				vim.api.nvim_set_current_tabpage(tab)
				vim.cmd(
					"tabmove " .. math.max(0, math.min((view.position or 1) - 1, #vim.api.nvim_list_tabpages() - 1))
				)
				if view.active then
					active = tab
				end
			else
				vim.notify(
					"Could not restore CodeDiff view: " .. tostring(err or "view did not open"),
					vim.log.levels.WARN
				)
			end
			next_view(index + 1)
		end
		vim.schedule(await_view)
	end
	next_view(1)
end

function M.suspend_for_save()
	if suspended then
		return
	end
	local state = M.capture()
	if #state.views == 0 then
		return
	end
	suspended = { state = state }
	-- Remove live diff tabs before mksession; the companion data retains their reopen instructions.
	local api = lifecycle()
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local session = api.get_session(tab)
		if session and not session.merge then
			-- A cancelled unsaved-buffer prompt must abort saving rather than serialize a half-closed view.
			if not api.close(tab) then
				suspended = nil
				error("CodeDiff session save cancelled: a diff tab could not close")
			end
		end
	end
end

function M.resume_after_save()
	local saved = suspended
	suspended = nil
	if saved and vim.v.exiting == vim.NIL then
		reopen(saved.state)
	end
end

function M.restore(done)
	local state = pending or {}
	pending = nil
	reopen(state, done)
end

return M
