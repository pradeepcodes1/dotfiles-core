-- expose one test workflow across languages and integrate Java debug runs.
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
		-- Test actions remain lazy triggers, with their definitions centralized.
		keys = require("core.keymaps").plugin.neotest,
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
