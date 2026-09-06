-- Run from the source root: nvim --headless -u NONE -l scripts/tests/workspace-symbols.lua
local source = vim.fn.getcwd() .. "/dot_config/nvim"
vim.opt.rtp:prepend(source)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
require("snacks").setup({ picker = { enabled = true } })
local workspace = require("core.workspace_symbols")
local project = require("core.project")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/nested", "p")
root = vim.uv.fs_realpath(root)
local queried, cancelled = {}, {}
local function symbol(name, file, line)
	return {
		name = name,
		kind = 12,
		location = {
			uri = vim.uri_from_fname(file),
			range = { start = { line = line or 0, character = 0 }, ["end"] = { line = line or 0, character = 1 } },
		},
	}
end
local function client(id, path, results, delay)
	return {
		id = id,
		name = "server" .. id,
		root_dir = path,
		initialized = true,
		offset_encoding = "utf-16",
		is_stopped = function()
			return false
		end,
		supports_method = function()
			return true
		end,
		cancel_request = function(_, request)
			cancelled[request] = true
		end,
		request = function(self, method, params, cb)
			queried[#queried + 1] = { id = self.id, method = method, query = params.query }
			local req = #queried
			if delay ~= false then
				vim.defer_fn(function()
					if method == "workspaceSymbol/resolve" then
						cb(nil, symbol(params.name, root .. "/resolved.lua"))
					else
						cb(nil, vim.deepcopy(results))
					end
				end, delay or 1)
			end
			return true, req
		end,
	}
end
local shared = symbol("shared", root .. "/shared.lua")
local a = client(1, root, { shared, symbol("external", root .. "-other/out.lua") })
local b = client(2, root .. "/nested", { shared, symbol("python", root .. "/nested/app.py") }, 15)
local other = client(3, root .. "-other", {})
local multi = client(4, nil, {})
multi.workspace_folders = { { name = "display name", uri = vim.uri_from_fname(root) } }
local unsupported = client(5, root, {})
unsupported.supports_method = function()
	return false
end
local initializing = client(6, root, {})
initializing.initialized = false
local stopped = client(7, root, {})
stopped.is_stopped = function()
	return true
end
local ancestor = client(8, vim.fs.dirname(root), {})
vim.lsp.get_clients = function()
	return { a, b, other, multi, unsupported, initializing, stopped, ancestor }
end
assert(vim.deep_equal(
	vim.tbl_map(function(c)
		return c.id
	end, workspace.clients(root)),
	{ 1, 2, 4, 8 }
))

-- Request every selected server before waiting, and support lazy resolution.
local unresolved =
	client(9, root, { { name = "lazy", kind = 12, location = { uri = vim.uri_from_fname(root .. "/resolved.lua") } } })
local emitted, complete = {}, false
workspace.request({ a, b, unresolved }, "search", function(_, values)
	vim.list_extend(emitted, values)
end, function(errors)
	assert(not next(errors))
	complete = true
end)
assert(#queried == 3, "requests must start concurrently")
assert(vim.wait(1000, function()
	return complete
end))
assert(#emitted == 5)
assert(queried[1].query == "search")

-- A stalled server cannot hold the picker forever; cancelled late replies are ignored.
local slow = client(10, root, {}, false)
complete = false
workspace.request({ slow }, "", function()
	error("unexpected result")
end, function(errors)
	assert(errors.server10 == "timed out")
	complete = true
end, 20)
local stalled_id = #queried
assert(vim.wait(1000, function()
	return complete
end))
assert(cancelled[stalled_id])
local late = client(11, root, { shared }, 20)
local cancel = workspace.request({ late }, "", function()
	error("cancelled result escaped")
end, function()
	error("cancelled query completed")
end)
local late_id = #queried
cancel()
assert(cancelled[late_id])
vim.wait(40, function()
	return false
end)

-- Exercise the actual Snacks finder, root filtering, dedup, and external toggle.
vim.lsp.get_clients = function()
	return { a, b, other }
end
project.set_open(true, root)
vim.api.nvim_buf_set_name(0, root .. "-other/foreground.txt")
local picker = workspace.open()
assert(vim.wait(2000, function()
	return not picker.finder.task:running()
end))
assert(#picker.finder.items == 2, vim.inspect(picker.finder.items))
assert(picker.title:find("server1, server2", 1, true))
picker.opts.external = true
picker:find()
assert(vim.wait(2000, function()
	return not picker.finder.task:running()
end))
assert(#picker.finder.items == 3)
picker:close()

-- One failed provider preserves healthy results and marks coverage incomplete.
local broken = client(12, root, {})
broken.request = function()
	return false
end
vim.lsp.get_clients = function()
	return { a, broken }
end
picker = workspace.open()
assert(vim.wait(2000, function()
	return not picker.finder.task:running()
end))
assert(#picker.finder.items == 1)
assert(picker.title:find("incomplete: server12", 1, true))
picker:close()

-- Closing a real picker cancels its outstanding requests.
vim.lsp.get_clients = function()
	return { slow }
end
local before = #queried
picker = workspace.open()
assert(vim.wait(1000, function()
	return #queried > before
end))
local closing_id = #queried
picker:close()
assert(vim.wait(1000, function()
	return cancelled[closing_id]
end))

vim.lsp.get_clients = function()
	return {}
end
picker = workspace.open()
assert(vim.wait(2000, function()
	return not picker.finder.task:running()
end))
assert(#picker.finder.items == 0)
assert(picker.title:find("no active servers", 1, true))
picker:close()

-- No project-wide query when file-only mode is selected.
project.set_open(false)
local fallback
Snacks.picker.lsp_workspace_symbols = function(opts)
	fallback = opts
	return opts
end
workspace.open()
assert(fallback and fallback.finder == nil)
vim.fn.delete(root, "rf")
print(
	"Workspace symbols: selection, concurrent requests, resolution, timeout, cancellation, picker merge/scope, and file-only fallback passed"
)
vim.cmd("qa!")
