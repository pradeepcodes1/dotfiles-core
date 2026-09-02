-- scope reference lookups to the open project rather than every indexed dependency.
local M = {}

-- gr. Language servers index more than the project: jdtls returns jdt://
-- virtual classfiles and attached JDK sources, and pyright/gopls reach into
-- site-packages and the module cache. `filter.cwd` drops everything outside
-- the project root, which also drops every non-file:// URI with it.
--
-- The picker's own defaults cover the rest of what this used to do by hand:
-- `include_current = false` hides the reference under the cursor, and
-- `auto_confirm = true` jumps straight there when only one survives.
function M.open_float()
	local project = require("core.project")
	if not project.is_open() then
		return
	end

	Snacks.picker.lsp_references({ filter = { cwd = project.current_root() } })
end

-- Locations a server hands us directly, rather than ones we requested --
-- ts_ls' `editor.action.showReferences` command (see plugins/masonlsp.lua).
function M.open_items(items, title)
	if not items or vim.tbl_isempty(items) then
		vim.notify("No references found", vim.log.levels.INFO)
		return false
	end

	vim.fn.setqflist({}, " ", { title = title or "References", items = items })
	Snacks.picker.qflist()
	return true
end

return M
