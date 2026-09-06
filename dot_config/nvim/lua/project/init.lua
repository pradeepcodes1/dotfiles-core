local M = {}

local project_paths = require("project.paths")
local project_state = require("project.state")
local project_pickers = require("project.actions.pickers")
local path_util = require("core.path")

local offered_roots = {}
local pending_roots = {}
local project_picker

local function startup_file()
	if vim.g.nvim_preview or vim.fn.argc() ~= 1 then
		return nil
	end

	local argument = vim.fn.argv(0)
	if type(argument) ~= "string" or argument == "" or argument == "-" or argument:match("^%w+://") then
		return nil
	end

	if vim.fn.isdirectory(argument) == 1 then
		return nil
	end

	return path_util.normalize(argument)
end

function M.offer(file)
	file = path_util.normalize(file)
	local root = file and project_paths.root(file) or nil
	if not file or not root or project_state.is_open() or project_state.restore_in_progress() then
		return false
	end
	if offered_roots[root] or pending_roots[root] then
		return false
	end

	local has_session = project_state.session_exists(root)
	pending_roots[root] = true
	vim.schedule(function()
		pending_roots[root] = nil
		if project_state.is_open() or project_state.restore_in_progress() then
			return
		end

		offered_roots[root] = true
		if has_session then
			project_pickers.open(file, root)
			return
		end

		local select = Snacks and Snacks.picker and Snacks.picker.select or vim.ui.select
		project_picker = select({ "Open project", "Keep file only" }, {
			prompt = ("Open as project `%s`?"):format(vim.fn.fnamemodify(root, ":t")),
		}, function(choice)
			project_picker = nil
			if choice == "Open project" then
				project_pickers.open(file, root)
			end
		end)
	end)

	return true
end

function M.setup()
	require("lsp.project_lsp").setup()
	project_state.set_open(false)
	vim.api.nvim_create_autocmd("BufEnter", {
		desc = "Offer project mode for files opened inside a project",
		callback = function(event)
			if vim.g.nvim_preview or vim.bo[event.buf].buftype ~= "" then
				return
			end
			local file = vim.api.nvim_buf_get_name(event.buf)
			if file ~= "" and not file:match("^%w+://") then
				M.offer(file)
			end
		end,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		desc = "Offer to open a file from its project session",
		once = true,
		callback = function()
			local requested_session = vim.env.NVIM_PROJECT_SESSION
			if requested_session and requested_session ~= "" then
				vim.env.NVIM_PROJECT_SESSION = nil
				project_state.set_open(true, requested_session:match("^([^|]+)"))
				vim.schedule(function()
					if
						not require("auto-session").restore_session(
							requested_session,
							{ is_startup_autorestore = true, show_message = false }
						)
					then
						project_state.set_open(false)
					end
				end)
				return
			end

			local argument = vim.fn.argc() == 1 and vim.fn.argv(0) or nil
			if argument and vim.fn.isdirectory(argument) == 1 then
				local root = project_paths.root(argument)
				project_state.set_open(root ~= nil, root)
				return
			end

			local file = startup_file()
			if file then
				M.offer(file)
			end
		end,
	})
end

return M
