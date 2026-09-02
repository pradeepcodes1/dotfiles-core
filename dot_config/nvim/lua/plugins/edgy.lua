-- give sidebars, tests, and debugger panels stable shared edge layouts.
return {
	"folke/edgy.nvim",
	enabled = not vim.g.nvim_preview,
	event = "VeryLazy",
	keys = {
		{
			"<leader>vs",
			function()
				require("edgy").toggle("left")
			end,
			desc = "View: Explorer + Symbols",
		},
		{
			"<leader>vd",
			function()
				-- Toggle debug view
				require("dapui").toggle()
			end,
			desc = "View: Debug",
		},
		{
			"<leader>vc",
			function()
				-- Close all sidebars, return to clean coding view
				pcall(function()
					require("edgy").close()
				end)
				pcall(function()
					require("dapui").close()
				end)
				pcall(function()
					require("neotest").summary.close()
				end)
			end,
			desc = "View: Code (close all)",
		},
	},
	opts = {
		animate = { enabled = false },
		-- Left sidebar: file explorer stacked above the symbol outline, sharing
		-- one 40-column edgebar. The edgebar width is the max width of its
		-- views, so both carry the same value. Explorer is auto-sized and takes
		-- whatever height Symbols leaves.
		-- Both views are pinned with their own `open`, which is what lets
		-- edgy.toggle("left") treat them as one sidebar. core/sidebar.lua used
		-- to do that by hand, including a WinClosed guard that polled up to 50
		-- times waiting for the second window to appear.
		left = {
			{
				title = "Explorer",
				ft = "neo-tree",
				filter = function(buf)
					return vim.b[buf].neo_tree_source == "filesystem"
				end,
				pinned = true,
				-- Not `Neotree show`: the explorer resolves a project root and
				-- reveals the current file inside it, and does not take focus,
				-- so Aerial attaches to the source buffer rather than the tree.
				open = function()
					require("core.neotree_explorer").show()
				end,
				size = { width = 40 },
				wo = { winbar = "%#EdgyTitle# Explorer%*" },
			},
			{
				title = "Symbols",
				ft = "aerial",
				pinned = true,
				open = "AerialOpen",
				size = { width = 40, height = 0.35 },
				wo = { winbar = "%#EdgyTitle# Symbols%*" },
			},
		},
		-- Bottom panel: debug repl/console and test output
		bottom = {
			{
				ft = "dap-repl",
				title = "REPL",
				size = { height = 12 },
			},
			{
				ft = "dapui_console",
				title = "Console",
				size = { height = 12 },
			},
			{
				ft = "neotest-output-panel",
				title = "Test Output",
				size = { height = 15 },
			},
		},
		-- Right sidebar: debug panels
		right = {
			{
				ft = "dapui_scopes",
				title = "Scopes",
				size = { width = 60 },
			},
			{
				ft = "dapui_breakpoints",
				title = "Breakpoints",
				size = { width = 60 },
			},
			{
				ft = "dapui_stacks",
				title = "Stacks",
				size = { width = 60 },
			},
			{
				ft = "dapui_watches",
				title = "Watches",
				size = { width = 60 },
			},
		},
		-- Window options for sidebar windows
		wo = {
			winbar = true,
			winfixwidth = true,
			winfixheight = true,
			winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
			signcolumn = "no",
			number = false,
			relativenumber = false,
			statusline = " ",
		},
	},
	config = function(_, opts)
		require("edgy").setup(opts)

		-- Aerial assigns the replacement outline buffer's filetype immediately
		-- after BufWinEnter. A synchronous Edgy scan sees the temporary empty
		-- filetype and moves that window out of the edgebar, so defer only this
		-- event by one scheduler tick. Keep Edgy's WinResized handler immediate.
		vim.api.nvim_clear_autocmds({ group = "edgy_layout", event = "BufWinEnter" })
		vim.api.nvim_create_autocmd("BufWinEnter", {
			group = "edgy_layout",
			desc = "Defer Edgy layout until buffer setup completes",
			callback = function()
				vim.schedule(require("edgy.layout").update)
			end,
		})
	end,
}
