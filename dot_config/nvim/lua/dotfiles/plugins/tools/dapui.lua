-- keep debugger controls and panels synchronized with DAP session state.
return {
	{
		"mfussenegger/nvim-dap",
		-- A function, so importing this spec never loads the key data.
		keys = function()
			return require("dotfiles.keymaps.specs").dap
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		keys = function()
			return require("dotfiles.keymaps.specs").dapui
		end,
		config = function()
			local dapui = require("dapui")
			-- setup() merges over its defaults, so a partial table is the
			-- documented call shape even though the parameter type is complete.
			---@diagnostic disable-next-line: missing-fields
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
				require("dotfiles.ui.dap").open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				require("dotfiles.ui.dap").close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				require("dotfiles.ui.dap").close()
			end
		end,
	},
}
