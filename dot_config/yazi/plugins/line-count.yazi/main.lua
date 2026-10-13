-- Yazi loads these plugins into its own Lua runtime, where `ya`, `ui`, `cx`,
-- `Status` and `Linemode` are supplied as globals. lua_ls indexes this repo as
-- one Neovim workspace, so nothing here can declare them -- a `.luarc.json`
-- beside this file only applies when lua_ls happens to root itself here rather
-- than at the repo, which it does not once a Neovim buffer opened first.
---@diagnostic disable: undefined-global

-- Count lines in a fetcher rather than a plugin `entry` task: Yazi treats
-- entry tasks as user jobs, so quitting while one was still running (right after
-- scrolling) asked to cancel it. Fetch tasks are background work that quit
-- ignores once `suppress_preload` is set in yazi.toml.
local LINES_CAP = 2 * 1024 * 1024

local function candidate(file)
	if not file then
		return nil
	end

	-- `cha` follows symlinks, so only resolved regular files are safe and meaningful to count.
	local perm = file.cha:perm()
	if not perm or perm:sub(1, 1) ~= "-" then
		return nil
	end

	local len = file.cha.len or 0
	if len > LINES_CAP then
		return nil
	end

	return {
		path = tostring(file.url),
		len = len,
		mtime = file.cha.mtime,
	}
end

-- Cached counts carry the size and mtime they were taken at, so an edited file
-- shows nothing until its refetch lands instead of a stale count.
local store = ya.sync(function(st, counts)
	for path, entry in pairs(counts) do
		st.counts[path] = entry
	end
	ui.render()
end)

return {
	setup = function(st)
		st.counts = {}

		Status:children_add(function(self)
			local item = candidate(self._current.hovered)
			local entry = item and st.counts[item.path]
			if not entry or entry.len ~= item.len or entry.mtime ~= item.mtime then
				return ""
			end

			return ui.Line({ ui.Span(string.format(" %dL", entry.lines)):fg("darkgray") })
		end, 2500, Status.LEFT)
	end,

	fetch = function(_, job)
		local counts = {}
		for _, file in ipairs(job.files) do
			local item = candidate(file)
			if item then
				local lines = 0
				if item.len > 0 then
					-- Command passes unusual filenames directly rather than through a shell.
					local output = Command("grep"):arg({ "-Ic", "", "--", item.path }):output()
					lines = output and output.status.success and tonumber(output.stdout) or nil
				end
				if lines then
					counts[item.path] = { lines = lines, len = item.len, mtime = item.mtime }
				end
			end
		end

		store(counts)
		return require("noop"):fetch(job)
	end,
}
