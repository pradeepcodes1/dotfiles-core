-- keep debugger controls and panels synchronized with DAP session state.
local function dap_action(action)
	return function()
		require("dap")[action]()
	end
end

return {
	{
		"mfussenegger/nvim-dap",
		keys = {
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
		},
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		keys = {
			{
				"<leader>vd",
				function()
					require("core.snacks_explorer").close_all()
					require("dapui").toggle()
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
		},
		config = function()
			local dapui = require("dapui")
			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.4 },
							{ id = "breakpoints", size = 0.2 },
							{ id = "stacks", size = 0.2 },
							{ id = "watches", size = 0.2 },
						},
						position = "right",
						size = 60,
					},
					{
						elements = {
							{ id = "repl", size = 0.5 },
							{ id = "console", size = 0.5 },
						},
						position = "bottom",
						size = 12,
					},
				},
			})

			-- Auto open/close dap-ui with debug sessions
			local dap = require("dap")
			dap.listeners.after.event_initialized["dapui_config"] = function()
				require("core.snacks_explorer").close_all()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},
}
