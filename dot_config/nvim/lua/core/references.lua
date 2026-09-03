-- scope reference lookups to the buffer's project rather than every indexed dependency.
local M = {}

-- gr. Language servers index more than the project: jdtls returns jdt://
-- virtual classfiles and attached JDK sources, and pyright/gopls reach into
-- site-packages and the module cache. picker_scope() drops everything outside
-- the root picker_root() resolves -- which takes every non-file:// URI with it,
-- since vim.uri_to_fname leaves those unchanged and they cannot match the root
-- -- and binds <C-.> to widen the picker back out to all of it.
--
-- That root is the open project when there is one, and otherwise the workspace
-- of the buffer's own language server, so gr still works on a file opened from
-- outside the project. A file belonging to no project scopes to nothing, which
-- leaves the picker unfiltered -- there is no root to hold it to.
--
-- The picker's own defaults cover the rest of what this used to do by hand:
-- `include_current = false` hides the reference under the cursor, and
-- `auto_confirm = true` jumps straight there when only one survives.
function M.open_float()
	local project = require("core.project")
	Snacks.picker.lsp_references(project.picker_scope(project.picker_root()))
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
