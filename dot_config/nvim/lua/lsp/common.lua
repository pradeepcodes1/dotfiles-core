-- give every language server the same diagnostics, capabilities, and keymaps.
-- lua/lsp/common.lua
local M = {}
local references = require("core.references")

vim.diagnostic.config({
	virtual_text = true, -- ← must be true (or table) for inline error text
})

-- Runs after a language server attaches to a buffer.
function M.on_attach(client, bufnr)
	-- Helper for shorter keymap lines
	local function nmap(lhs, rhs, desc)
		if desc then
			desc = "LSP: " .. desc
		end
		vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
	end
	-- Basic navigation & actions
	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	nmap("gD", vim.lsp.buf.declaration, "Go to Declaration")
	nmap("gr", references.open_float, "[G]oto [R]eferences")
	nmap("K", vim.lsp.buf.hover, "Hover Documentation")
	nmap("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
	nmap("<leader>la", vim.lsp.buf.code_action, "Code action")

	-- Format on save is handled by conform in plugins/conform.lua.
end

return M
