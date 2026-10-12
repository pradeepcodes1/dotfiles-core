-- Yazi loads these plugins into its own Lua runtime, where `ya`, `ui`, `cx`,
-- `Status` and `Linemode` are supplied as globals. lua_ls indexes this repo as
-- one Neovim workspace, so nothing here can declare them -- a `.luarc.json`
-- beside this file only applies when lua_ls happens to root itself here rather
-- than at the repo, which it does not once a Neovim buffer opened first.
---@diagnostic disable: undefined-global

-- Show useful text-file line counts without repeatedly scanning on every redraw.
local LINES_CAP = 2 * 1024 * 1024
local DEBOUNCE_SECONDS = 0.15

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

	local path = tostring(file.url)
	return {
		path = path,
		empty = len == 0,
	}
end

local current_candidate = ya.sync(function(st, generation)
	if st.generation ~= generation then
		return nil
	end

	return candidate(cx.active.current.hovered)
end)

local publish_count = ya.sync(function(st, generation, lines)
	if st.generation ~= generation then
		return
	end

	-- Keep only the active row's result; every later hover deliberately recounts it.
	st.lines = lines
	ui.render()
end)

return {
	setup = function(st)
		st.generation, st.lines = 0, nil

		local function schedule_count()
			st.generation = st.generation + 1
			st.lines = nil
			-- Each hover gets a cheap sleeping task; only the latest generation is
			-- allowed to launch grep after the cursor has settled for 150ms.
			ya.emit("plugin", { st._id, tostring(st.generation) })
		end

		ps.sub("hover", schedule_count)
		schedule_count()

		Status:children_add(function(self)
			local item = candidate(self._current.hovered)
			if not item then
				return ""
			end

			if type(st.lines) ~= "number" then
				return ""
			end

			return ui.Line({ ui.Span(string.format(" %dL", st.lines)):fg("darkgray") })
		end, 2500, Status.LEFT)
	end,

	entry = function(_, job)
		local generation = tonumber(job.args[1])
		if not generation then
			return
		end

		ya.sleep(DEBOUNCE_SECONDS)
		local item = current_candidate(generation)
		if not item then
			return
		end

		if item.empty then
			publish_count(generation, 0)
			return
		end

		-- Command keeps the scan off the synchronous status-rendering path and
		-- passes unusual filenames directly rather than through a shell.
		local output = Command("grep"):arg({ "-Ic", "", "--", item.path }):output()
		local lines = output and output.status.success and tonumber(output.stdout) or false
		publish_count(generation, lines)
	end,
}
