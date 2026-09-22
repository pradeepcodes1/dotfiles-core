-- give every language server the same diagnostics, capabilities, and keymaps.
local M = {}

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
	local function nmap(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
	end
	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	nmap("gD", vim.lsp.buf.declaration, "Go to Declaration")
	nmap("grr", require("dotfiles.lsp.references").open_float, "[G]oto [R]eferences")
	nmap("K", vim.lsp.buf.hover, "Hover Documentation")
	nmap("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
	vim.keymap.set({ "n", "x" }, "<leader>ll", vim.lsp.buf.code_action, { buffer = bufnr, desc = "LSP: Code action" })
	-- Format on save is handled by conform in plugins/lsp/conform.lua.
end

return M
