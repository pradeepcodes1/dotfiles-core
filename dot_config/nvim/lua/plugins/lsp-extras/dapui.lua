-- keep debugger controls and panels synchronized with DAP session state.
return {
	{
		"mfussenegger/nvim-dap",
		-- DAP controls are declared centrally while still loading DAP on demand.
		keys = require("core.keymaps").plugin.dap,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		-- DAP UI bindings share the central registry with the core DAP controls.
		keys = require("core.keymaps").plugin.dapui,
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

			-- Debug-session events share the manual tab lifecycle so every entry path behaves alike.
			local dap = require("dap")
			dap.listeners.after.event_initialized["dapui_config"] = function()
				require("ui.dap").open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				require("ui.dap").close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				require("ui.dap").close()
			end
		end,
	},
}
