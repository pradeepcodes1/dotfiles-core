-- feed Copilot through the completion menu instead of competing ghost-text
-- and panel UIs. The blink-copilot provider is declared in plugins/blink.lua.
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
				suggestion = { enabled = false }, -- ghost text competes with the menu
				panel = { enabled = false }, -- the menu is the only surface
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
}
