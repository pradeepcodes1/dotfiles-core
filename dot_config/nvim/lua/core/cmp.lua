-- merge LSP and Copilot candidates into one completion UI with deliberate keys.
local cmp = require("cmp")
cmp.setup({
	sources = {
		{ name = "nvim_lsp" },
		{ name = "copilot" },
	},
	mapping = cmp.mapping.preset.insert({
		["<C-k>"] = cmp.mapping.select_prev_item(), -- Previous item
		["<C-j>"] = cmp.mapping.select_next_item(), -- Next item
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(), -- Manually trigger completion
		["<C-e>"] = cmp.mapping.abort(), -- Close completion
		["<CR>"] = cmp.mapping.confirm({ select = false }), -- Confirm selection
	}),
})
