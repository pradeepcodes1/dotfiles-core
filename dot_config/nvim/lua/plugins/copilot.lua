-- feed Copilot through cmp instead of competing ghost-text and panel UIs.
-- lazy.nvim spec
return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false }, -- Disable ghost text, use cmp instead
				panel = { enabled = false }, -- Disable panel, use cmp instead
				filetypes = {
					java = false,
				},
			})
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		config = function()
			-- Keep compatibility with Neovim's method-form client API.
			local source = require("copilot_cmp.source")
			source.is_available = function(self)
				local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
				return not self.client:is_stopped()
					and self.client.name == "copilot"
					and next(get_clients({
							bufnr = vim.api.nvim_get_current_buf(),
							id = self.client.id,
						}))
						~= nil
			end

			require("copilot_cmp").setup()
		end,
	},
}
