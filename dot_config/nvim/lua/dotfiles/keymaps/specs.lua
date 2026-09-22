-- Declarative key data for lazy.nvim triggers: every binding here belongs to a
-- plugin that must stay unloaded until the key is pressed, so lazy needs the
-- lhs list before the plugin exists. Specs read this through a function, so
-- importing a spec never loads this file.
--
-- Only user-facing bindings live here. A plugin's internal key table (blink's
-- completion keys, a picker's window keys) stays in that plugin's own spec.
-- Bindings that are always live are in keymaps/init.lua.
local M = {}

M.snacks = {
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
			Snacks.lazygit({ cwd = require("dotfiles.project.paths").current_root() })
		end,
		desc = "Lazygit",
	},
	{
		"<leader>gf",
		function()
			Snacks.picker.git_status({ cwd = require("dotfiles.project.paths").current_root() })
		end,
		desc = "Git changed files",
	},
	{
		"<leader>gp",
		function()
			Snacks.picker.gh_pr({ cwd = require("dotfiles.project.paths").current_root() })
		end,
		desc = "GitHub pull requests",
	},
	{
		"<leader>gi",
		function()
			Snacks.picker.gh_issue({ cwd = require("dotfiles.project.paths").current_root() })
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

M.flash = {
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

M.overseer = {
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

M.neotest = {
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

M.dap = {
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

M.dapui = {
	{
		"<leader>vd",
		function()
			require("dotfiles.ui.dap").toggle()
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

M.conform = {
	{
		"<leader>lf",
		function()
			require("conform").format({ async = true, lsp_format = "fallback" })
		end,
		mode = { "n", "x" },
		desc = "LSP: Format buffer or selection",
	},
}

return M
