-- normalize LSP and quickfix references into the shared Trouble preview float.
local M = {}

local REFERENCES_MODE = "lsp_references_float"
local QFLIST_MODE = "references_qflist_float"
local trouble_float = require("core.trouble_float")

function M.open_float()
	trouble_float.focus_first_item(trouble_float.get(true).open(REFERENCES_MODE))
end

function M.open_items_float(items, title, context)
	if not items or vim.tbl_isempty(items) then
		vim.notify("No references found", vim.log.levels.INFO)
		return false
	end

	vim.fn.setqflist({}, " ", {
		title = title or "References",
		items = items,
		context = context,
	})

	trouble_float.focus_first_item(trouble_float.get(true).open(QFLIST_MODE))
	return true
end

return M
