-- keep cross-plugin navigation and actions in one discoverable key layer.
local map = vim.keymap.set
local problems = require("core.problems")
local project = require("core.project")
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
	require("core.snacks_explorer").close_all()
	pcall(function()
		require("dapui").close()
	end)
	pcall(function()
		require("neotest").summary.close()
	end)
end

-- Pickers. `fg` and `ft` are project-only, since a directory-wide ripgrep needs
-- a directory to be meaningful; `fS` is not, because picker_root() can ask the
-- buffer's own language server which workspace it indexed. `ff` stays available
-- everywhere but file_search_root() keeps it off `/` and $HOME.
-- Inside any file picker, dotfiles are shown and gitignored files are not:
-- `<a-h>` hides the former, `<C-.>`/`<a-i>` reveals the latter.
if not vim.g.nvim_preview then
	map("n", "<leader>ff", function()
		local root = project.file_search_root()
		if root then
			Snacks.picker.files({ cwd = root })
		end
	end, { desc = "Find Files" })
	map(
		"n",
		"<leader>fg",
		project.only(function()
			Snacks.picker.grep({ cwd = project.current_root() })
		end),
		{ desc = "Grep project" }
	)
	map(
		"n",
		"<leader>fw",
		project.only(function()
			Snacks.picker.grep_word({ cwd = project.current_root() })
		end),
		{ desc = "Find word in project" }
	)
	map("n", "<leader>fu", function()
		Snacks.picker.undo()
	end, { desc = "Find undo history" })
	map("n", "<leader>fb", function()
		Snacks.picker.buffers()
	end, { desc = "Find open buffers" })
	map("n", "<leader>/", function()
		Snacks.picker.lines()
	end, { desc = "Search lines in buffer" })
	map("n", "<leader>fs", function()
		Snacks.picker.lsp_symbols()
	end, { desc = "Find symbols in file" })
	map("n", "<leader>fS", function()
		Snacks.picker.lsp_workspace_symbols(project.picker_scope(project.picker_root()))
	end, { desc = "Find symbols in workspace" })
	map("n", "<leader>fr", function()
		Snacks.picker.recent()
	end, { desc = "Recent files" })
	map("n", "<leader>`", function()
		Snacks.picker.buffers()
	end, { desc = "Search open buffers" })
	map("n", "<leader>s", function()
		vim.cmd("AerialToggle! right")
	end, { desc = "View: Symbols" })
	map("n", "<leader>e", function()
		require("core.snacks_explorer").toggle()
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
map("n", "<leader>vp", project.only(problems.show_workspace), { desc = "View: Problems (project)" })
map("n", "<leader>vP", problems.show_buffer, { desc = "View: Problems (buffer)" })
map("n", "<leader>vq", function()
	Snacks.picker.qflist()
end, { desc = "View: Quickfix" })
map("n", "<leader>vr", project.only(problems.refresh_workspace), { desc = "View: Refresh Problems" })
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
-- A count multiplies the ten-column/line step; arrows remain aliases.
for _, resize in ipairs({
	{ "h", "<Left>", "vertical resize -", "narrower" },
	{ "l", "<Right>", "vertical resize +", "wider" },
	{ "k", "<Up>", "resize +", "taller" },
	{ "j", "<Down>", "resize -", "shorter" },
}) do
	for _, key in ipairs({ resize[1], resize[2] }) do
		map("n", "<leader>w" .. key, function()
			vim.cmd(resize[3] .. (10 * vim.v.count1))
		end, { desc = "Resize split " .. resize[4] })
	end
end
map("n", "<leader>w=", "<C-w>=", { desc = "Equalize splits" })

local opts = { noremap = true, silent = true }

-- BarBar keymaps; unavailable in preview mode (barbar.nvim disabled there,
-- see plugins/barbar.lua) — skip registering to avoid dangling E492 errors.
if not vim.g.nvim_preview then
	-- The dashboard is a startup screen only. Closing the last buffer leaves
	-- barbar's own empty [No Name] buffer (see barbar/bbye.lua), which is what
	-- an editor with nothing open should look like.
	map("n", "<leader>q", "<Cmd>BufferClose<CR>", { noremap = true, silent = true, desc = "Close buffer" })
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
	map("n", "<leader>pp", project.pick_session, { desc = "Project: Switch" })
	map("n", "<leader>po", project.open_current, { desc = "Project: Open current root" })
	map("n", "<leader>pd", project.delete_session, { desc = "Project: Delete session" })
	map("n", "<leader>pi", project.info, { desc = "Project: Info" })
	map(
		"n",
		"<leader>pr",
		project.only(function()
			close_panels()
			project.reset()
		end),
		{ desc = "Project: Reset workspace" }
	)
	map("n", "<leader>pn", project.open_new_window, { desc = "Project: New window" })
	map("n", "<leader>pt", project.open_terminal, { desc = "Project: Terminal at root" })
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

if not vim.g.nvim_preview then
	for i = 1, 9 do
		map("n", "<leader>" .. i, "<Cmd>BufferGoto " .. i .. "<CR>", { silent = true, desc = "Go to buffer " .. i })
	end
	map("n", "<leader>0", "<Cmd>BufferPin<CR>", { silent = true, desc = "Pin buffer" })

	local move_keys = { "!", "@", "#", "$", "%", "^", "&", "*", "(" }
	for i, key in ipairs(move_keys) do
		map(
			"n",
			"<leader>" .. key,
			"<Cmd>BufferMove " .. i .. "<CR>",
			{ silent = true, desc = "Move buffer to slot " .. i }
		)
	end
end

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
	project.only(function()
		Snacks.picker.todo_comments({ cwd = project.current_root() })
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
