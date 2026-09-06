local M = {}

local project_paths = require("project.paths")
local project_state = require("project.state")
local path_util = require("core.path")
local cli = require("core.cli")

--- The window holding a previous M.info() render, if one is still open.
local function info_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.b[vim.api.nvim_win_get_buf(win)].project_info then
			return win
		end
	end
end

--- Sized to the widest line it holds, since these are paths and tables read
--- across rather than down. Recomputed as the async blocks land.
local function fit_info_width(buf)
	local window = info_window()
	if not window then
		return
	end

	local width = 0
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	vim.api.nvim_win_set_width(window, math.min(math.max(width + 2, 40), 80))
end

--- `render` is the render this block belongs to. A second <leader>pi while an
--- onefetch is still walking the history would otherwise append that run's
--- output underneath the new one.
local function append_info(buf, render, lines)
	if not vim.api.nvim_buf_is_valid(buf) or vim.b[buf].project_info_render ~= render or #lines == 0 then
		return
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, vim.list_extend({ "" }, lines))
	vim.bo[buf].modifiable = false
	fit_info_width(buf)
end

--- The repository summary Kitty's cmd+shift+i shows, same tools, same flags,
--- same order. Both are handed `git rev-parse --show-toplevel` rather than the
--- project root: from a subdirectory onefetch reports the whole repo while
--- tokei counts only that subtree, so two different paths would print two
--- answers about two different trees. Their line counts still differ by design,
--- since onefetch counts only its default `programming markup` types.
---
--- Chained rather than run together, so the order is the script's order, and
--- async because onefetch walks the history -- the roots above are the part
--- worth having immediately, and they are already on screen when these land.
local function append_repo_stats(buf, render, toplevel)
	local tools = {
		{ "onefetch", "--no-art", "--no-color-palette", "--nerd-fonts", toplevel },
		{ "tokei", toplevel },
	}

	local function run(index)
		local cmd = tools[index]
		if not cmd then
			return
		end
		if not cli.has(cmd[1]) then
			return run(index + 1)
		end

		vim.system(cmd, { text = true, env = cli.no_color }, function(result)
			vim.schedule(function()
				local text = vim.trim((result.code == 0 and result.stdout or result.stderr) or "")
				if text == "" then
					text = ("%s exited %d with no output"):format(cmd[1], result.code)
				end
				append_info(buf, render, vim.split(cli.strip_ansi(text), "\n", { plain = true }))
				run(index + 1)
			end)
		end)
	end

	run(1)
end

--- Every root this instance is holding, side by side. The scoping failures
--- this config has hit -- jdtls' cwd-named workspace, fS scoped to a root the
--- servers never indexed -- all look identical from the outside (an empty
--- picker) and all come apart the moment these are printed together.
---
--- A right-hand split rather than a notification: these are long paths read
--- against each other, and a toast that times out mid-comparison is the wrong
--- shape for that. Pressing the key again re-renders in place instead of
--- stacking a second pane. The repository summary follows once it arrives.

function M.info()
	-- Gathered before the split exists. Every one of these answers for the
	-- current buffer, which the scratch pane is about to become.
	local root = project_paths.current_root()
	local lines = {
		("mode:        %s"):format(project_state.is_open() and "project" or "file only"),
		("root:        %s"):format(root or "none"),
		("cwd:         %s"):format(path_util.cwd() or "none"),
		("branch:      %s"):format(cli.git_branch(root) or "none"),
		("session:     %s"):format(project_state.current_session_name() or "not loaded"),
		("saved:       %s"):format(root and project_state.session_exists(root) and "yes" or "no"),
		("buffer root: %s"):format(project_paths.buffer_root() or "none"),
		("picker root: %s"):format(project_paths.picker_root() or "unscoped"),
	}

	vim.list_extend(lines, require("lsp.project_lsp").info(root))

	local clients = vim.lsp.get_clients({ bufnr = 0 })
	table.insert(lines, ("clients:     %s"):format(#clients == 0 and "none" or ""))
	for _, client in ipairs(clients) do
		table.insert(lines, ("  %s  %s"):format(client.name, client.root_dir or "no root"))
	end

	local window = info_window()
	local buf
	if window then
		vim.api.nvim_set_current_win(window)
		buf = vim.api.nvim_win_get_buf(window)
	else
		buf = vim.api.nvim_create_buf(false, true)
		vim.b[buf].project_info = true
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "projectinfo"
		vim.api.nvim_buf_set_name(buf, "Project Info")
		-- `q` closes read-only panes here the way it closes a preview window;
		-- buffer-local, so macro recording is untouched everywhere else.
		vim.keymap.set("n", "q", "<C-w>c", { buffer = buf, desc = "Close project info" })

		vim.cmd("botright vsplit")
		vim.api.nvim_win_set_buf(0, buf)
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
		vim.wo.wrap = false
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	fit_info_width(buf)

	local render = (vim.b[buf].project_info_render or 0) + 1
	vim.b[buf].project_info_render = render
	local toplevel = cli.git_toplevel(root)
	if toplevel then
		append_repo_stats(buf, render, toplevel)
	end

	return true
end

return M
