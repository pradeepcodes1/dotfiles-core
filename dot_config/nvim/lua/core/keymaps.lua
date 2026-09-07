-- keep cross-plugin navigation and actions in one discoverable key layer.
local map = vim.keymap.set
local problems = require("lsp.problems")
local project_pickers = require("project.actions.pickers")
local project_deleter = require("project.actions.deleter")
local project_info = require("project.info")
local project_reset = require("project.actions.reset")
local project_state = require("project.state")
local project_paths = require("project.paths")
vim.g.mapleader = " "

-- Yank context. Keep the prefix unmapped so complete shortcuts never wait.
for key, target in pairs({
	p = { "project", "project path" },
	r = { "relative", "relative file path" },
	a = { "absolute", "absolute file path" },
	n = { "filename", "filename" },
	c = { "commit", "Git HEAD commit" },
	b = { "branch", "Git branch name" },
}) do
	map("n", "<leader>y" .. key, function()
		require("core.yank").copy(target[1])
	end, { desc = "Yank " .. target[2] })
end

-- basics
map("i", "jk", "<Esc>", { desc = "Exit insert mode with jk" })
-- No visual-mode `jk`: there, both halves are motions, so any run of `j`
-- ending in a `k` inside timeoutlen drops the selection instead of moving
-- up a line. `q` below, plain <Esc>, and re-pressing v/V all leave visual
-- mode without that. Insert mode keeps `jk`, where neither key is a motion.
map("t", "<C-Space>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
map("v", "q", "<Esc>", { desc = "Exit visual mode with q" })

-- Keep native centering on zz; silently ignore fold toggles outside folds.
map("n", "za", function()
	if vim.fn.foldlevel(vim.fn.line(".")) == 0 then
		return
	end
	vim.cmd("normal! za")
end, { desc = "Toggle fold" })

-- Panels that own their own teardown. Closing their windows directly would
-- leave dapui and neotest believing they are still open, so both <leader>vc and
-- the project reset go through this.
local function close_panels()
	require("ui.explorer_controller").close_all()
	pcall(function()
		-- Close the owning debug tab as well as its dap-ui windows.
		require("ui.dapui").close()
	end)
	pcall(function()
		require("neotest").summary.close()
	end)
end

-- Pickers. `fz`, `fw`, and `ft` are project-only, since a directory-wide search needs
-- a directory to be meaningful. `fS` queries all active project servers in
-- project mode, and the buffer's servers in file-only mode. `ff` and `fg` also
-- recognize a marker root around a directly opened file; `ff` alone falls back
-- to that file's parent when no project marker exists.
-- fff owns file and text search; Snacks remains the picker for buffers, symbols,
-- history, diagnostics, projects, and plugin-specific sources.
if not vim.g.nvim_preview then
	local function fff_at(root)
		-- fff snapshots cwd when its config module first loads, which can precede
		-- auto-session's project restore. Seed the intended root before fff's
		-- native index initializes to avoid racing a home scan with this one.
		require("fff.conf").get().base_path = root
		return require("fff")
	end

	map("n", "<leader>ff", function()
		local root = project_paths.file_search_root()
		if root then
			fff_at(root).find_files({ cwd = root })
		end
	end, { desc = "Find Files" })
	map("n", "<leader>fg", function()
		local root = project_paths.project_search_root()
		if root then
			fff_at(root).live_grep({ cwd = root })
		end
	end, { desc = "Grep project" })
	map(
		{ "n", "x" },
		"<leader>fw",
		project_state.only(function()
			local root = project_paths.current_root()
			fff_at(root).live_grep_under_cursor({ cwd = root })
		end),
		{ desc = "Find word/selection in project" }
	)
	map(
		"n",
		"<leader>fz",
		project_state.only(function()
			local root = project_paths.current_root()
			fff_at(root).live_grep({
				cwd = root,
				grep = { modes = { "fuzzy", "plain" } },
			})
		end),
		{ desc = "Fuzzy grep project" }
	)
	map("n", "<leader>fu", function()
		Snacks.picker.undo()
	end, { desc = "Find undo history" })
	map("n", "<leader>fb", function()
		require("ui.harpoon_buffers").open()
	end, { desc = "Find open buffers" })
	map("n", "<leader>/", function()
		Snacks.picker.lines()
	end, { desc = "Search lines in buffer" })
	map("n", "<leader>s", function()
		-- LuaLS reports table entries as variables, objects, arrays, and keys, so
		-- include every symbol kind instead of hiding most of the document tree.
		Snacks.picker.lsp_symbols({ filter = { default = true, lua = true } })
	end, { desc = "Find symbols in file" })
	-- Uppercase S keeps workspace symbols beside the document-symbol picker.
	map("n", "<leader>S", function()
		require("lsp.workspace_symbols").open()
	end, { desc = "Find symbols in workspace" })
	map("n", "<leader>fr", function()
		Snacks.picker.recent()
	end, { desc = "Recent files" })
	map("n", "<leader>`", function()
		require("ui.harpoon_buffers").open()
	end, { desc = "Search open buffers" })
	map("n", "<leader>e", function()
		require("ui.explorer_controller").toggle()
	end, { desc = "View: Explorer" })
	map("n", "<leader>vc", close_panels, { desc = "View: Code (close all)" })
end

-- LSP (gd, rename, code_action are in lsp/common.lua on_attach)
map("n", "<leader>lc", "<Cmd>cclose<CR>", { desc = "Close quickfix window" })
map("n", "<leader>ld", function()
	vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Open diagnostic float" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
map("n", "<leader>lh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })
map("n", "<leader>vp", project_state.only(problems.show_workspace), { desc = "View: Problems (project)" })
map("n", "<leader>vP", problems.show_buffer, { desc = "View: Problems (buffer)" })
map("n", "<leader>vq", function()
	Snacks.picker.qflist()
end, { desc = "View: Quickfix" })
map("n", "<leader>vr", project_state.only(problems.refresh_workspace), { desc = "View: Refresh Problems" })
map("n", "<leader>ud", function()
	vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Toggle diagnostics" })
map("n", "[p", function()
	local ok, aerial = pcall(require, "aerial")
	if ok then
		local ok_symbols, symbols = pcall(aerial.get_location, false)
		if ok_symbols and symbols and #symbols > 1 then
			aerial.prev_up()
			return
		end
	end

	vim.cmd("normal! [[")
end, { desc = "Parent symbol" })

-- Split navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to split above" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to split below" })
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Move to left split" })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Move to right split" })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Move to split above" })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Move to split below" })
-- The resize Hydra owns <leader>w so one prefix can start several adjustments.

local opts = { noremap = true, silent = true }

-- Harpoon owns the curated file list. Snacks closes buffers without collapsing
-- the window layout; preview mode remains a single file.
if not vim.g.nvim_preview then
	map("n", "<leader>q", function()
		Snacks.bufdelete()
	end, { desc = "Close buffer" })
end

-- Project management. auto-session owns the cwd: its session list is keyed on
-- directory + git branch, so the session picker *is* the project picker, and it
-- restores the buffers and layout rather than only changing directory.
--
-- <leader>p is a prefix rather than the picker itself: everything under it acts
-- on the project as a whole, where the f group finds things inside one. Nothing
-- here is a second spelling of an f-group key -- ff, fg, fS and ft are already
-- project-rooted. plugins/init.lua names the group for which-key; the `Project:`
-- desc prefix is what labels each entry under it.
--
-- The whole group is off in preview mode, where the window is one read-only
-- file in a float: restoring a session into it is nothing anyone wants.
if not vim.g.nvim_preview then
	-- Keep project restoration behind one explicit picker instead of inferring it from the current file.
	map("n", "<leader>pp", project_pickers.pick_session, { desc = "Project: Switch" })
	map("n", "<leader>pd", project_deleter.delete_session, { desc = "Project: Delete session" })
	map("n", "<leader>pi", project_info.info, { desc = "Project: Info" })
	map("n", "<leader>pl", function()
		require("lsp.project_lsp").toggle()
	end, { desc = "Project: Toggle automatic LSP startup" })
	map(
		"n",
		"<leader>pr",
		project_state.only(function()
			close_panels()
			project_reset.reset()
		end),
		{ desc = "Project: Reset workspace" }
	)
	map("n", "<leader>pn", project_pickers.open_new_window, { desc = "Project: New window" })
	map("n", "<leader>pt", project_pickers.open_terminal, { desc = "Project: Terminal at root" })
end

-- Splits
map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>\\", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>x", "<C-w>c", { desc = "Close split" })
map("n", "<leader>X", "<Cmd>tabclose<CR>", { desc = "Close tab page" })
map("n", "<leader><Tab>", "<Cmd>tabnext<CR>", { desc = "Next tab page" })
map("n", "<leader><S-Tab>", "<Cmd>tabprevious<CR>", { desc = "Previous tab page" })

-- Preserve native macro recording in the editor and pager-style quit in preview.
if vim.g.nvim_preview then
	map("n", "q", ":qa<CR>", { desc = "Quit preview" })
else
	map("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>", { desc = "Clear search highlighting" })
end

map("i", "<A-Left>", "<C-o>b", opts) -- back one word
map("i", "<A-Right>", "<C-o>w", opts) -- forward one word

local function is_diffview_open()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
		if ft == "DiffviewFiles" or ft == "DiffviewFileHistory" then
			return true
		end
	end
	return false
end

local function diffview_review()
	vim.cmd("DiffviewOpen")
end

local function diffview_file()
	vim.cmd("DiffviewOpen -- %")
	vim.cmd("DiffviewToggleFiles")
end

local function diffview_close()
	if is_diffview_open() then
		vim.cmd("DiffviewClose")
	end
end

map("n", "<leader>gD", diffview_review, { desc = "Diffview review" })
map("n", "<leader>gd", diffview_file, { desc = "Diffview current file" })
map("n", "<leader>gc", diffview_close, { desc = "Diffview close" })
map("n", "<leader>gh", function()
	local file = vim.api.nvim_buf_get_name(0)
	if file ~= "" then
		vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(file))
	end
end, { desc = "Git file history" })
-- A colon mapping supplies the actual visual range to Diffview's line history.
map("x", "<leader>gh", ":DiffviewFileHistory<CR>", { desc = "Git selected-line history" })

map("n", "<leader>Q", "<cmd>qa<CR>", {
	noremap = true,
	silent = true,
	desc = "Quit Neovim",
})

-- Yazi file manager
map({ "n", "v" }, "<leader>E", "<cmd>Yazi<cr>", { desc = "Open yazi at current file" })
map("n", "<c-up>", "<cmd>Yazi toggle<cr>", { desc = "Resume last yazi session" })

-- Todo-comments. The source registers itself with Snacks.picker on setup.
map(
	"n",
	"<leader>ft",
	project_state.only(function()
		Snacks.picker.todo_comments({ cwd = project_paths.current_root() })
	end),
	{ desc = "Find TODOs in project" }
)
map("n", "]t", function()
	require("todo-comments").jump_next()
end, { desc = "Next TODO" })
map("n", "[t", function()
	require("todo-comments").jump_prev()
end, { desc = "Previous TODO" })

-- Copy the full notification history to the clipboard. Not under <leader>.,
-- which snacks uses for the scratch buffer: a two-key binding below it makes
-- every scratch toggle wait out timeoutlen first.
map("n", "<leader>N", function()
	local ok, notifier = pcall(require, "snacks.notifier")
	if not ok then
		vim.notify("Snacks notifier is not available", vim.log.levels.WARN)
		return
	end

	local history = notifier.get_history()
	local lines = {}
	for _, entry in ipairs(history) do
		local header =
			string.format("[%s] %s", entry.level, entry.title and entry.title ~= "" and entry.title or "notify")
		table.insert(lines, header)
		vim.list_extend(lines, vim.split(entry.msg, "\n", { plain = true }))
		table.insert(lines, "")
	end

	if #lines == 0 then
		vim.notify("No notifications to copy", vim.log.levels.INFO)
		return
	end

	local text = table.concat(lines, "\n")
	vim.fn.setreg("+", text)
	vim.fn.setreg('"', text)
	vim.notify(string.format("Copied %d notifications", #history), vim.log.levels.INFO)
end, { desc = "Copy all notifications to clipboard" })
