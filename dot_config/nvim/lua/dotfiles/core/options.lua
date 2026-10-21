-- define editor-wide behavior once before plugins specialize it.
local opt = vim.opt
local group = vim.api.nvim_create_augroup("core_options", { clear = true })
vim.filetype.add({
	pattern = {
		-- Detect the rendered filename so templates inherit native syntax and ftplugins.
		[".*%.tmpl"] = function(path, bufnr)
			local filename = path:gsub("%.tmpl$", "")
			local parent = vim.fs.dirname(filename)
			local name = vim.fs.basename(filename)
			-- Chezmoi source attributes are not part of names such as .gitconfig.
			for _, prefix in ipairs({ "private_", "readonly_", "executable_" }) do
				name = name:gsub("^" .. prefix, "")
			end
			name = name:gsub("^dot_", ".")
			return vim.filetype.match({ filename = vim.fs.joinpath(parent, name), buf = bufnr })
		end,
	},
})

opt.number = true
opt.relativenumber = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.updatetime = 300
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.ignorecase = true
-- An uppercase letter in the pattern makes the search case-sensitive again,
-- so /Foo no longer also matches foo without typing \C.
opt.smartcase = true
-- Preview :s substitutions live, with off-screen matches listed in a split.
opt.inccommand = "split"
opt.cursorline = true
-- Wrap is off by default; the autocmd below turns it on only in windows
-- showing real file buffers, so sidebars and panels never wrap.
opt.wrap = false
-- Break at word boundaries and keep wrapped lines aligned with their indent.
opt.linebreak = true
opt.breakindent = true
-- Mark continuation rows so a wrapped line doesn't read as several lines.
opt.showbreak = "↪ "
opt.confirm = true
-- One border style for every float: core LSP/diagnostic windows use it
-- directly, and snacks, blink, mason and yazi fall back to it when unset.
opt.winborder = "rounded"

-- Persistent undo
opt.undofile = true

-- Treesitter-based folding (start with all folds open)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99

-- Spell checking for prose
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = { "markdown", "gitcommit", "text" },
	desc = "Spell check prose filetypes",
	callback = function()
		-- `spell` is window-local, `spelllang` buffer-local; opt_local blurred that.
		vim.wo.spell = true
		vim.bo.spelllang = "en_us"
	end,
})

-- Wrap only file buffers (buftype ""): plugin views like the gitsigns blame
-- sidebar are scratch/nofile and must stay unwrapped to line up with code.
-- FileType re-checks because some plugins set buftype after the window opens.
local function apply_file_window_options(buf)
	local is_file = vim.bo[buf].buftype == ""
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_get_config(win).relative == "" then
			vim.wo[win].wrap = is_file
			-- comfy-line-numbers draws signs through %s, so with the default "auto"
			-- the gutter appears and vanishes as gitsigns/diagnostics come and go,
			-- shifting the code sideways. Reserve it in file windows only. [0] is
			-- :setlocal, so the global stays "auto" and a plugin panel opened from
			-- a file window starts from that instead of inheriting an empty gutter.
			if is_file then
				vim.wo[win][0].signcolumn = "yes"
			end
		end
	end
end
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
	group = group,
	desc = "Wrap and reserve the sign column only in file buffers",
	callback = function(args)
		apply_file_window_options(args.buf)
	end,
})

-- Relative numbers only in the focused window outside insert and cmdline mode;
-- other splits show absolute lines, so a line someone quotes matches what you
-- see. Inlined from nvim-numbertoggle, whose global checks needed more patching
-- than the plugin had code. Windows that turned 'number' off (dashboard,
-- pickers) never get a bare relative column.
local function relative_numbers(win, on)
	if vim.api.nvim_win_is_valid(win) then
		vim.wo[win].relativenumber = on and vim.wo[win].number
	end
end
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "WinEnter" }, {
	group = group,
	desc = "Relative numbers in the focused window",
	callback = function()
		relative_numbers(0, vim.api.nvim_get_mode().mode ~= "i")
	end,
})
vim.api.nvim_create_autocmd({ "FocusLost", "InsertEnter", "CmdlineEnter" }, {
	group = group,
	desc = "Absolute numbers while typing or unfocused",
	callback = function(args)
		relative_numbers(0, false)
		-- Repaint so a typed :range sees the absolute column; input() and
		-- :insert must not redraw (neovim#32068).
		if
			args.event == "CmdlineEnter"
			and vim.wo.number
			and not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype)
		then
			vim.cmd.redraw()
		end
	end,
})
vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
	group = group,
	desc = "Absolute numbers in the window you left",
	callback = function()
		local win = vim.api.nvim_get_current_win()
		-- Decided once the loop settles and without a forced redraw:
		-- nvim_win_call (Snacks building its explorer split) switches windows and
		-- back without WinEnter, and a synchronous redraw painted that split half-built.
		vim.schedule(function()
			if win ~= vim.api.nvim_get_current_win() then
				relative_numbers(win, false)
			end
		end)
	end,
})

-- Smooth scrolling options
opt.scrolloff = 8 -- Keep 8 lines visible above/below cursor
opt.sidescrolloff = 8 -- Keep 8 columns visible left/right of cursor
opt.smoothscroll = true -- Enable smooth scrolling (Neovim 0.10+)
-- Trackpad swipes drift sideways and kitty turns that into horizontal wheel
-- ticks; hor:0 drops them so vertical scrolling stays straight. zh/zl still
-- scroll nowrap windows.
opt.mousescroll = "ver:3,hor:0"

-- Report the terminal title so kitty tabs name themselves after the buffer
-- instead of showing the shell. Was disabled to avoid clashing with the tmux
-- status bar, which kitty's tab bar replaces.
-- Filename first: the tab bar is vertical, so leading text is what survives
-- truncation. "+" marks an unsaved buffer.
opt.title = true
if vim.g.nvim_preview then
	opt.titlestring = "Neovide Preview · %t"
else
	-- Must be a global for `v:lua`; namespaced so the root table stays clean.
	_G.MyConfig = _G.MyConfig or {}
	_G.MyConfig.project_title = function()
		local root = require("project-manager.root").current() or vim.fn.getcwd()
		return vim.fn.fnamemodify(root, ":t") .. " · " .. root
	end
	-- Kitty's tab bar is narrow, so the terminal title is just "<project> - vi",
	-- falling back to the file name outside a project. Neovide has room for the
	-- full filename · project · path title.
	_G.MyConfig.short_title = function()
		local root = require("project-manager.root").current()
		local name = root and vim.fn.fnamemodify(root, ":t") or vim.fn.expand("%:t")
		return (name ~= "" and name or "nvim") .. " - vi"
	end
	if vim.g.neovide then
		-- Named workspace tabs (CodeDiff, Debug) keep their identity on utility buffers.
		opt.titlestring = "%{get(t:, 'tabname', expand('%:t'))}%( %M%) · %{v:lua.MyConfig.project_title()}"
	else
		opt.titlestring = "%{v:lua.MyConfig.short_title()}"
	end
end
vim.g.health = vim.tbl_deep_extend("force", vim.g.health or {}, { style = "float" })
-- format_on_save is handled by plugins/lsp/conform.lua
-- Focus and buffer entry only. CursorHold/CursorHoldI made this stat every
-- loaded buffer on the 300ms updatetime above, including mid-keystroke.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
	group = group,
	desc = "Reload buffers changed outside Neovim",
	callback = function()
		if vim.fn.mode() ~= "c" and vim.bo.buftype == "" then
			vim.cmd.checktime()
		end
	end,
})

-- Restore terminal cursor to underscore on exit (prevents vim block cursor persisting)
if not vim.g.neovide then
	vim.api.nvim_create_autocmd("VimLeave", {
		group = group,
		desc = "Restore the terminal cursor shape on exit",
		callback = function()
			if #vim.api.nvim_list_uis() == 0 then
				return
			end

			vim.o.guicursor = "a:hor20"
			io.write("\027[4 q")
		end,
	})
end
