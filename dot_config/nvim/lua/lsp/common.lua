-- give every language server the same diagnostics, capabilities, and keymaps.
-- lua/lsp/common.lua
local M = {}
local references = require("core.references")

-- The cursor line renders its diagnostics in full as virtual lines, and drops
-- the truncated virtual text that would otherwise say the same thing twice on
-- the same row. Every other line keeps the inline one-liner. core/diagnostics.lua
-- used to do this by wrapping the virtual_text handler and refcounting
-- suppressed lines; `current_line` is the same idea in the diagnostic API.
vim.diagnostic.config({
	virtual_lines = { current_line = true },
	virtual_text = { current_line = false },
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
