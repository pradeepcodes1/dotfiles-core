-- expose one test workflow across languages and integrate Java debug runs.
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

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"rcasia/neotest-java",
		},
		keys = {
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
			-- <leader>vt summary toggle is in the view keybinds below
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
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-java")({
						ignore_wrapper = false,
					}),
				},
				icons = {
					passed = "✓",
					running = "●",
					failed = "✗",
					skipped = "↓",
					unknown = "?",
				},
				floating = {
					border = "rounded",
					max_height = 0.8,
					max_width = 0.8,
				},
			})

			-- Patch nvim-java's enrich_config to handle attach requests (used by neotest-java)
			-- Without this, debugging tests fails because attach requests don't have mainClass
			local ok, DapSetup = pcall(require, "java-dap.setup")
			if ok then
				local orig_enrich = DapSetup.enrich_config
				function DapSetup:enrich_config(config)
					if config.request == "attach" then
						return vim.deepcopy(config)
					end
					return orig_enrich(self, config)
				end
			end
		end,
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
		opts = {},
	},
}
