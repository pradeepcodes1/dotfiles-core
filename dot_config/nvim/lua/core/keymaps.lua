-- keep cross-plugin navigation and actions in one discoverable key layer.
local map = vim.keymap.set
local M = {}
local problems = require("lsp.problems")
local project_pickers = require("project.actions.pickers")
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
	require("ui.explorer").close_all()
	pcall(function()
		-- Close the owning debug tab as well as its dap-ui windows.
		require("ui.dap").close()
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
			-- Reset and normal file search share the same preview defaults and toggle.
			require("ui.find_files").open(root)
		end
	end, { desc = "Find Files" })
	map("n", "<leader>fg", function()
		local root = project_paths.project_search_root()
		if root then
			-- Put fuzzy first so project grep opens there and only cycles to regex.
			fff_at(root).live_grep({ cwd = root, grep = { modes = { "fuzzy", "regex" } } })
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
		-- Use the standard buffer picker; Harpoon has its own menu.
		Snacks.picker.buffers()
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
		-- Use the standard buffer picker; Harpoon has its own menu.
		Snacks.picker.buffers()
	end, { desc = "Search open buffers" })
	map("n", "<leader>e", function()
		require("ui.explorer").toggle()
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
	-- Open folders through the same Yazi chooser used by the dashboard.
	map("n", "<leader>po", project_pickers.open_directory, { desc = "Project: Open directory in new window" })
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

-- CodeDiff toggles its current view; only close when this tab belongs to it.
-- Reuse the whole-review tab instead of toggling it closed or opening another copy.
map("n", "<leader>gD", function()
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		if vim.t[tab].codediff_mode == "explorer" then
			vim.api.nvim_set_current_tabpage(tab)
			return
		end
	end
	vim.cmd("CodeDiff")
end, { desc = "CodeDiff review" })
map("n", "<leader>gd", "<cmd>CodeDiff file HEAD<CR>", { desc = "CodeDiff current file" })
map("n", "<leader>gc", function()
	if vim.t.codediff_view then
		vim.cmd("CodeDiff")
	end
end, { desc = "CodeDiff close" })
map("n", "<leader>gh", function()
	if vim.api.nvim_buf_get_name(0) ~= "" then
		vim.cmd("CodeDiff history %")
	end
end, { desc = "Git file history" })
-- Keep the visual range so history follows only the selected lines.
map("x", "<leader>gh", ":CodeDiff history<CR>", { desc = "Git selected-line history" })

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

-- Lazy plugin specs consume these groups so every user-facing binding remains discoverable here.
M.plugin = {}

M.blink = {
	preset = "enter",
	["<C-k>"] = { "select_prev", "fallback" },
	["<C-j>"] = { "select_next", "fallback" },
	["<C-b>"] = { "scroll_documentation_up", "fallback" },
	["<C-f>"] = { "scroll_documentation_down", "fallback" },
}

M.snacks_dashboard = {
	{
		icon = " ",
		key = "o",
		desc = "Open Project",
		action = function()
			require("project.actions.pickers").open_directory()
		end,
	},
	{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
	{
		icon = " ",
		key = "r",
		desc = "Recent Files",
		action = function()
			Snacks.picker.recent()
		end,
	},
	{ icon = "", key = "p", desc = "Projects", action = "<leader>pp" },
	{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
}

M.snacks_picker_keys = {
	input = { keys = { ["<c-.>"] = { "toggle_ignored", mode = { "i", "n" } } } },
	list = { keys = { ["<c-.>"] = "toggle_ignored" } },
}

M.snacks_explorer_keys = {
	["."] = "toggle_ignored",
	q = "close_explorer",
	["<C-q>"] = "close_explorer",
	Q = "close_explorer",
	["<leader>x"] = "close_explorer",
	["<C-w>c"] = "close_explorer",
	["<C-w>q"] = "close_explorer",
}

M.project_picker_keys = {
	input = { keys = { ["<c-.>"] = { "toggle_external", mode = { "i", "n" } } } },
	list = { keys = { ["<c-.>"] = "toggle_external" } },
}

M.plugin.snacks = {
	{
		"<leader>z",
		function()
			Snacks.zen()
		end,
		desc = "Toggle Zen Mode",
	},
	{
		"<leader>.",
		function()
			Snacks.scratch()
		end,
		desc = "Toggle Scratch Buffer",
	},
	{
		"<leader>>",
		function()
			Snacks.scratch.select()
		end,
		desc = "Select Scratch Buffer",
	},
	{
		"<leader>gg",
		function()
			Snacks.lazygit({ cwd = require("project.paths").current_root() })
		end,
		desc = "Lazygit",
	},
	{
		"<leader>gf",
		function()
			Snacks.picker.git_status({ cwd = require("project.paths").current_root() })
		end,
		desc = "Git changed files",
	},
	{
		"<leader>gp",
		function()
			Snacks.picker.gh_pr({ cwd = require("project.paths").current_root() })
		end,
		desc = "GitHub pull requests",
	},
	{
		"<leader>gi",
		function()
			Snacks.picker.gh_issue({ cwd = require("project.paths").current_root() })
		end,
		desc = "GitHub issues",
	},
}

function M.harpoon()
	local keys = {
		{
			"<leader>m",
			function()
				require("harpoon"):list():add()
			end,
			desc = "Marks: Add current file",
		},
		{
			"<leader>mm",
			function()
				local harpoon = require("harpoon")
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end,
			desc = "Marks: Open Harpoon menu",
		},
		{
			"<leader>mp",
			function()
				require("harpoon"):list():prev()
			end,
			desc = "Marks: Previous file",
		},
		{
			"<leader>mn",
			function()
				require("harpoon"):list():next()
			end,
			desc = "Marks: Next file",
		},
		{
			"<leader><leader>",
			function()
				-- Double leader opens Harpoon's editable list rather than the ordinary buffer picker.
				local harpoon = require("harpoon")
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end,
			desc = "Marks: Open Harpoon menu",
		},
	}
	for index = 1, 9 do
		local slot = index
		table.insert(keys, {
			"<leader>" .. slot,
			function()
				require("harpoon"):list():select(slot)
			end,
			desc = "Harpoon: Go to file " .. slot,
		})
	end
	return keys
end

M.plugin.flash = {
	{
		"s",
		mode = { "n", "x", "o" },
		function()
			require("flash").jump()
		end,
		desc = "Flash",
	},
	{
		"S",
		mode = { "n", "x", "o" },
		function()
			require("flash").treesitter()
		end,
		desc = "Flash Treesitter",
	},
	{
		"r",
		mode = "o",
		function()
			require("flash").remote()
		end,
		desc = "Remote Flash",
	},
	{
		"R",
		mode = { "o", "x" },
		function()
			require("flash").treesitter_search()
		end,
		desc = "Treesitter Search",
	},
	{
		"<c-s>",
		mode = "c",
		function()
			require("flash").toggle()
		end,
		desc = "Toggle Flash Search",
	},
}

M.plugin.overseer = {
	{ "<leader>or", "<Cmd>OverseerRun<CR>", desc = "Overseer: Run task" },
	{ "<leader>ot", "<Cmd>OverseerToggle<CR>", desc = "Overseer: Toggle tasks" },
	{ "<leader>os", "<Cmd>OverseerShell<CR>", desc = "Overseer: Run shell command" },
	{ "<leader>oa", "<Cmd>OverseerTaskAction<CR>", desc = "Overseer: Task action" },
}

local function neotest_action(section, action, get_argument)
	return function()
		local callback = require("neotest")[section][action]
		if get_argument then
			callback(get_argument())
		else
			callback()
		end
	end
end

M.plugin.neotest = {
	{ "<leader>tl", neotest_action("run", "run_last"), desc = "Test: Rerun last (same strategy)" },
	{ "<leader>tt", neotest_action("run", "run"), desc = "Test: Run nearest" },
	{
		"<leader>tf",
		neotest_action("run", "run", function()
			return vim.fn.expand("%")
		end),
		desc = "Test: Run file",
	},
	{
		"<leader>td",
		neotest_action("run", "run", function()
			return { strategy = "dap" }
		end),
		desc = "Test: Debug nearest",
	},
	{
		"<leader>to",
		neotest_action("output", "open", function()
			return { enter = true }
		end),
		desc = "Test: Output",
	},
	{ "<leader>tO", neotest_action("output_panel", "toggle"), desc = "Test: Output panel" },
	{ "<leader>tS", neotest_action("run", "stop"), desc = "Test: Stop" },
	{ "<leader>vt", neotest_action("summary", "toggle"), desc = "View: Tests" },
}

local function dap_action(action)
	return function()
		require("dap")[action]()
	end
end

M.plugin.dap = {
	{
		"<leader>dB",
		function()
			vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
				if condition and vim.trim(condition) ~= "" then
					require("dap").set_breakpoint(condition)
				end
			end)
		end,
		desc = "Conditional breakpoint",
	},
	{ "<leader>db", dap_action("toggle_breakpoint"), desc = "Toggle breakpoint" },
	{ "<leader>dc", dap_action("continue"), desc = "Continue / Start" },
	{ "<leader>do", dap_action("step_over"), desc = "Step over" },
	{ "<leader>di", dap_action("step_into"), desc = "Step into" },
	{ "<leader>dO", dap_action("step_out"), desc = "Step out" },
	{
		"<leader>dr",
		function()
			require("dap").repl.toggle()
		end,
		desc = "Toggle REPL",
	},
	{ "<leader>dl", dap_action("run_last"), desc = "Run last" },
	{ "<leader>dx", dap_action("terminate"), desc = "Terminate" },
}

M.plugin.dapui = {
	{
		"<leader>vd",
		function()
			require("ui.dap").toggle()
		end,
		desc = "View: Debug",
	},
	{
		"<leader>de",
		function()
			require("dapui").eval()
		end,
		mode = { "n", "v" },
		desc = "Eval expression",
	},
}

M.plugin.conform = {
	{
		"<leader>lf",
		function()
			require("conform").format({ async = true, lsp_format = "fallback" })
		end,
		mode = { "n", "x" },
		desc = "LSP: Format buffer or selection",
	},
}

-- Buffer-local mappings are installed on demand but declared here for one-source discovery.
function M.close_project_info(buf)
	map("n", "q", "<C-w>c", { buffer = buf, desc = "Close project info" })
end

function M.close_lsp_log(buf)
	map("n", "q", "<Cmd>close<CR>", { buffer = buf, desc = "Close LSP log" })
end

function M.yazi_project_confirm(buffer, confirm)
	map("t", "<c-o>", confirm, { buffer = buffer, desc = "Open current directory as project" })
end

function M.lsp_on_attach(bufnr)
	local function nmap(lhs, rhs, desc)
		map("n", lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
	end
	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	nmap("gD", vim.lsp.buf.declaration, "Go to Declaration")
	nmap("grr", require("lsp.references").open_float, "[G]oto [R]eferences")
	nmap("K", vim.lsp.buf.hover, "Hover Documentation")
	nmap("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
	map({ "n", "x" }, "<leader>ll", vim.lsp.buf.code_action, { buffer = bufnr, desc = "LSP: Code action" })
end

function M.java_on_attach(bufnr, smart_definition, smart_references)
	-- Java replaces only the navigation actions that need import-aware fallbacks.
	map("n", "gd", smart_definition, { buffer = bufnr, desc = "LSP/Java: [G]oto [D]efinition (import-aware)" })
	map("n", "grr", smart_references, { buffer = bufnr, desc = "LSP/Java: [G]oto [R]eferences (import-aware)" })
end

function M.codediff_navigation()
	map("n", "<leader>h", function()
		require("ui.codediff_hydra").activate()
	end, {
		desc = "CodeDiff navigation",
		nowait = true,
	})
end

function M.neovide()
	local function zoom(factor)
		return function()
			local current = vim.g.neovide_scale_factor or 1
			vim.g.neovide_scale_factor = factor == 0 and 1 or math.min(math.max(current * factor, 0.5), 3)
		end
	end
	map({ "n", "i", "v" }, "<D-s>", function()
		vim.cmd.write()
	end, { desc = "Save" })
	map("v", "<D-c>", function()
		vim.cmd([[normal! "+y]])
	end, { silent = true, desc = "Copy" })
	map({ "n", "i", "v", "c", "t" }, "<D-v>", function()
		vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
	end, { silent = true, desc = "Paste" })
	local zoom_modes = { "n", "i", "v", "c", "t" }
	for _, binding in ipairs({
		{ "<D-=>", 1.1, "Increase" },
		{ "<D-+>", 1.1, "Increase" },
		{ "<D-->", 1 / 1.1, "Decrease" },
		{ "<D-0>", 0, "Reset" },
	}) do
		map(zoom_modes, binding[1], zoom(binding[2]), { silent = true, desc = binding[3] .. " font size" })
	end
end

function M.neoscroll()
	local neoscroll = require("neoscroll")
	local function scroll(lines, move_cursor, duration)
		return function()
			neoscroll.scroll(lines, { move_cursor = move_cursor, duration = duration })
		end
	end
	local function action(name, duration, duration_key)
		return function()
			neoscroll[name]({ [duration_key or "duration"] = duration })
		end
	end
	-- These replace native scrolling only after neoscroll has initialized.
	for lhs, callback in pairs({
		["<ScrollWheelUp>"] = scroll(-13, true, 70),
		["<ScrollWheelDown>"] = scroll(13, true, 70),
		["<C-u>"] = action("ctrl_u", 150),
		["<C-d>"] = action("ctrl_d", 150),
		["<C-b>"] = action("ctrl_b", 250),
		["<C-f>"] = action("ctrl_f", 250),
		["<C-y>"] = scroll(-0.1, false, 50),
		["<C-e>"] = scroll(0.1, false, 50),
		["zt"] = action("zt", 100, "half_win_duration"),
		["zz"] = action("zz", 100, "half_win_duration"),
		["zb"] = action("zb", 100, "half_win_duration"),
	}) do
		map({ "n", "v" }, lhs, callback)
	end
end

function M.treesitter_textobjects(select, move)
	local function textobject(action, query)
		return function()
			action(query, "textobjects")
		end
	end
	local select_modes = { "x", "o" }
	map(select_modes, "af", textobject(select.select_textobject, "@function.outer"), { desc = "Around function" })
	map(select_modes, "if", textobject(select.select_textobject, "@function.inner"), { desc = "Inside function" })
	map(select_modes, "ac", textobject(select.select_textobject, "@class.outer"), { desc = "Around class" })
	map(select_modes, "ic", textobject(select.select_textobject, "@class.inner"), { desc = "Inside class" })
	map(select_modes, "aa", textobject(select.select_textobject, "@parameter.outer"), { desc = "Around parameter" })
	map(select_modes, "ia", textobject(select.select_textobject, "@parameter.inner"), { desc = "Inside parameter" })
	local move_modes = { "n", "x", "o" }
	map(move_modes, "]m", textobject(move.goto_next_start, "@function.outer"), { desc = "Next function start" })
	map(move_modes, "]]", textobject(move.goto_next_start, "@class.outer"), { desc = "Next class start" })
	map(move_modes, "]a", textobject(move.goto_next_start, "@parameter.inner"), { desc = "Next parameter" })
	map(move_modes, "]M", textobject(move.goto_next_end, "@function.outer"), { desc = "Next function end" })
	map(move_modes, "][", textobject(move.goto_next_end, "@class.outer"), { desc = "Next class end" })
	map(move_modes, "[m", textobject(move.goto_previous_start, "@function.outer"), { desc = "Previous function start" })
	map(move_modes, "[[", textobject(move.goto_previous_start, "@class.outer"), { desc = "Previous class start" })
	map(move_modes, "[a", textobject(move.goto_previous_start, "@parameter.inner"), { desc = "Previous parameter" })
	map(move_modes, "[M", textobject(move.goto_previous_end, "@function.outer"), { desc = "Previous function end" })
	map(move_modes, "[]", textobject(move.goto_previous_end, "@class.outer"), { desc = "Previous class end" })
end

function M.gitsigns_on_attach(bufnr, gitsigns, hunk_hydra)
	local opts = { buffer = bufnr, silent = true }
	-- Dispatch the shared prefix by tab so ordinary and CodeDiff buffers can coexist.
	map("n", "<leader>h", function()
		if vim.t.codediff_view then
			require("ui.codediff_hydra").activate()
		else
			hunk_hydra:activate()
		end
	end, vim.tbl_extend("force", opts, { desc = "Git / CodeDiff hunk navigation", nowait = true }))
	for _, action in ipairs({
		{ "hs", "stage_hunk", "Stage/unstage Git hunk" },
		{ "hr", "reset_hunk", "Discard working-tree hunk changes" },
	}) do
		map("x", "<leader>" .. action[1], function()
			local first, last = vim.fn.line("v"), vim.fn.line(".")
			gitsigns[action[2]]({ math.min(first, last), math.max(first, last) })
		end, vim.tbl_extend("force", opts, { desc = action[3] .. " (selection)" }))
	end
	map("n", "]h", function()
		gitsigns.nav_hunk("next")
	end, vim.tbl_extend("force", opts, { desc = "Next Git hunk" }))
	map("n", "[h", function()
		gitsigns.nav_hunk("prev")
	end, vim.tbl_extend("force", opts, { desc = "Previous Git hunk" }))
	map("n", "<leader>gb", gitsigns.blame, vim.tbl_extend("force", opts, { desc = "Blame current file" }))
end

function M.gitsigns_hydra_heads(gitsigns)
	-- Hydra's modal keys belong with the bindings even though Hydra consumes this table itself.
	return {
		{
			"j",
			function()
				gitsigns.nav_hunk("next")
			end,
			{ desc = "next" },
		},
		{
			"k",
			function()
				gitsigns.nav_hunk("prev")
			end,
			{ desc = "previous" },
		},
		{ "p", gitsigns.preview_hunk, { desc = "preview" } },
		{
			"b",
			function()
				gitsigns.blame_line({ full = true })
			end,
			{ desc = "blame" },
		},
		{ "s", gitsigns.stage_hunk, { desc = "stage/unstage" } },
		{ "u", gitsigns.undo_stage_hunk, { desc = "undo stage" } },
		{ "r", gitsigns.reset_hunk, { desc = "reset" } },
		{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
		{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
	}
end

function M.resize_hydra_heads()
	local function resize(command)
		return function()
			vim.cmd(command .. (10 * vim.v.count1))
		end
	end
	-- Arrow and home-row spellings perform the same modal resize operations.
	return {
		{ "h", resize("vertical resize -"), { desc = "narrower" } },
		{ "<Left>", resize("vertical resize -"), { desc = "narrower" } },
		{ "l", resize("vertical resize +"), { desc = "wider" } },
		{ "<Right>", resize("vertical resize +"), { desc = "wider" } },
		{ "j", resize("resize -"), { desc = "shorter" } },
		{ "<Down>", resize("resize -"), { desc = "shorter" } },
		{ "k", resize("resize +"), { desc = "taller" } },
		{ "<Up>", resize("resize +"), { desc = "taller" } },
		{ "=", "<C-w>=", { desc = "equalize" } },
		{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
		{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
	}
end

function M.codediff_hydra_heads(diff, navigate_file, hunk_action)
	-- CodeDiff supplies the actions while this table owns their modal keys.
	return {
		{ "j", diff.next_hunk, { desc = "Next hunk" } },
		{ "k", diff.prev_hunk, { desc = "Previous hunk" } },
		{ "<C-j>", navigate_file("next"), { desc = "Next file / history commit" } },
		{ "<C-k>", navigate_file("prev"), { desc = "Previous file / history commit" } },
		{ "s", hunk_action("stage"), { desc = "Stage hunk" } },
		{ "u", hunk_action("unstage"), { desc = "Unstage hunk" } },
		{ "r", hunk_action("discard"), { desc = "Discard hunk" } },
		{ "q", function() end, { exit = true, nowait = true } },
		{ "<Esc>", nil, { exit = true } },
	}
end

return M
