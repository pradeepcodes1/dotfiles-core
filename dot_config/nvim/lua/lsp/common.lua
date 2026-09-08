-- give every language server the same diagnostics, capabilities, and keymaps.
-- lua/lsp/common.lua
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
	-- Attach-time scope is preserved while the binding declarations stay central.
	require("core.keymaps").lsp_on_attach(bufnr)
	-- Format on save is handled by conform in plugins/conform.lua.
end

return M
