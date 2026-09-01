-- feed Copilot through cmp instead of competing ghost-text and panel UIs.
-- lazy.nvim spec
return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		-- A preview window is one read-only buffer; a language server there can
		-- only cost a process and a keychain prompt.
		enabled = not vim.g.nvim_preview,
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false }, -- Disable ghost text, use cmp instead
				panel = { enabled = false }, -- Disable panel, use cmp instead
				-- Pin the interpreter instead of taking `node` off PATH. Neovide
				-- spawns nvim through `zsh -c`, which does not source .zshrc and so
				-- never activates mise, leaving Homebrew's node -- ad-hoc signed,
				-- with a build hash for an identifier -- to ask the keychain for the
				-- Copilot token. macOS cannot pin a durable ACL entry to that, so
				-- the prompt returns on every launch. The mise shim resolves without
				-- activation and lands on a Developer ID binary, whose grant sticks.
				copilot_node_command = vim.fn.expand("~/.local/share/mise/shims/node"),
				filetypes = {
					java = false,
				},
			})
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		enabled = not vim.g.nvim_preview,
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
