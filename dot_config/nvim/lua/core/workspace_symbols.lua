-- Workspace requests belong to the open project, not the foreground buffer.
local M = {}
local project = require("core.project")
local path_util = require("core.path")

function M.clients(root)
	local clients = {}
	local function overlaps(path)
		path = path_util.normalize(path)
		return path and (path_util.under(path, root) or path_util.under(root, path))
	end
	for _, client in ipairs(vim.lsp.get_clients()) do
		local belongs = overlaps(client.root_dir) or overlaps(client.config and client.config.root_dir)
		for _, folder in ipairs(client.workspace_folders or (client.config and client.config.workspace_folders) or {}) do
			local ok, path = pcall(vim.uri_to_fname, folder.uri or "")
			belongs = belongs or overlaps(ok and path or folder.name)
		end
		if
			belongs
			and client.initialized
			and not client:is_stopped()
			and client:supports_method("workspace/symbol")
		then
			clients[#clients + 1] = client
		end
	end
	table.sort(clients, function(a, b)
		return a.name == b.name and a.id < b.id or a.name < b.name
	end)
	return clients
end

-- Main-thread request coordinator. Every query owns its requests and deadline;
-- cancelling a picker never cancels another feature's LSP work.
-- Resolve URI-only WorkspaceSymbols before handing them to Snacks, which
-- expects locations with ranges for both previewing and jumping.
function M.request(clients, query, emit, done, timeout_ms)
	local requests, errors = {}, {}
	local pending, starting, stopped = 0, true, false
	local timer
	local function cancel_pending()
		for _, request in ipairs(requests) do
			if not request.finished and request.id then
				pcall(request.client.cancel_request, request.client, request.id)
			end
		end
	end
	local function stop(cancel)
		if stopped then
			return
		end
		stopped = true
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		if cancel then
			cancel_pending()
		end
	end
	local function complete()
		if not stopped and not starting and pending == 0 then
			stop(false)
			done(errors)
		end
	end
	local send
	send = function(client, method, params, receive)
		local request = { client = client, finished = false }
		requests[#requests + 1] = request
		pending = pending + 1
		local function finish(err, result)
			if stopped or request.finished then
				return
			end
			request.finished = true
			if err then
				errors[client.name] = err.message or tostring(err)
			elseif result then
				local ok, failure = pcall(receive, result)
				if not ok then
					errors[client.name] = tostring(failure)
				end
			end
			pending = pending - 1
			complete()
		end
		local ok, accepted, id = pcall(client.request, client, method, params, finish)
		request.id = id
		if not ok or not accepted then
			finish({ message = ok and "request rejected" or tostring(accepted) })
		end
	end
	for _, client in ipairs(clients) do
		send(client, "workspace/symbol", { query = query }, function(symbols)
			local ready = {}
			for _, symbol in ipairs(symbols) do
				if symbol.location and symbol.location.range then
					ready[#ready + 1] = symbol
				elseif symbol.location and client:supports_method("workspaceSymbol/resolve") then
					send(client, "workspaceSymbol/resolve", symbol, function(resolved)
						if resolved.location and resolved.location.range then
							emit(client, { resolved })
						end
					end)
				end
			end
			emit(client, ready)
		end)
	end
	starting = false
	complete()
	if not stopped then
		timer = vim.defer_fn(function()
			for _, request in ipairs(requests) do
				if not request.finished then
					errors[request.client.name] = "timed out"
				end
			end
			stop(true)
			done(errors)
		end, timeout_ms or 8000)
	end
	return function()
		stop(true)
	end
end

function M.finder(root)
	return function(_, ctx)
		local clients = M.clients(root)
		local names = vim.tbl_map(function(client)
			return client.name
		end, clients)
		ctx.picker.title = "Project symbols · " .. (#names > 0 and table.concat(names, ", ") or "no active servers")
		local lsp = require("snacks.picker.source.lsp")
		local bufmap = lsp.bufmap()
		return function(cb)
			local async = ctx.async
			local queue, seen = {}, {}
			local finished, errors, cancel = false, {}, nil
			async:on(
				"abort",
				vim.schedule_wrap(function()
					if cancel then
						cancel()
					end
				end)
			)
			async:schedule(function()
				if async:aborted() then
					return
				end
				cancel = M.request(clients, ctx.filter.search or "", function(client, symbols)
					local items = lsp.results_to_items(client, symbols, { text_with_file = true })
					for _, item in ipairs(items) do
						item.buf = bufmap[item.file]
						item.tree = false
						queue[#queue + 1] = item
					end
					async:resume()
				end, function(failures)
					finished, errors = true, failures
					async:resume()
				end)
			end)
			while true do
				local batch = queue
				queue = {}
				for _, item in ipairs(batch) do
					local key = table.concat({ item.file, item.name, item.kind, item.pos[1], item.pos[2] }, "\0")
					if not seen[key] then
						seen[key] = true
						cb(item)
					end
				end
				if finished and #queue == 0 then
					break
				end
				if #queue == 0 then
					async:suspend()
				end
			end
			if next(errors) then
				async:schedule(function()
					local failed = vim.tbl_keys(errors)
					table.sort(failed)
					ctx.picker.title = "Project symbols · incomplete: " .. table.concat(failed, ", ")
					ctx.picker:update_titles()
				end)
			end
		end
	end
end

function M.open()
	-- Preserve file-only mode's buffer-local server selection and scope.
	if not project.is_open() then
		return Snacks.picker.lsp_workspace_symbols(project.picker_scope(project.picker_root()))
	end
	local root = project.current_root()
	if not root then
		vim.notify("No open project root", vim.log.levels.WARN)
		return
	end
	local opts = project.picker_scope(root)
	opts.finder = M.finder(root)
	-- This Snacks version defers picker teardown but resets finder.task before
	-- its aborted coroutine necessarily unwinds. Finish that unwind while the
	-- matcher still exists, so closing during a request cannot touch a nil UI.
	opts.on_close = function(picker)
		local task = picker.finder.task
		task:abort()
		task:step()
	end
	-- Across languages, show every symbol kind instead of applying the active
	-- buffer's language-specific kind filter to unrelated servers' results.
	opts.filter = { default = true }
	return Snacks.picker.lsp_workspace_symbols(opts)
end

return M
