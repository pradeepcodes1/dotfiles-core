local M = {}

local project_state = require("project.state")
-- Keep missing projects visible until explicitly pruned. An inaccessible
-- directory is not evidence that its saved session should be removed.
function M.stale_session(item)
	local root = item.session_name:match("^([^|]+)")
	if not root then
		return false
	end
	local stat, _, code = vim.uv.fs_stat(root)
	return (stat and stat.type ~= "directory") or code == "ENOENT" or code == "ENOTDIR"
end

function M.prune_stale_sessions()
	local sessions = require("auto-session")
	local removed = 0
	for _, item in ipairs(project_state.session_list()) do
		if M.stale_session(item) and sessions.delete_session_file(item.path, item.display_name) then
			removed = removed + 1
		end
	end
	vim.notify(("Pruned %d stale project session%s"):format(removed, removed == 1 and "" or "s"))
	return removed
end

return M
