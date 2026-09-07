-- Show useful text-file line counts without repeatedly scanning on every redraw.
local LINES_CAP = 2 * 1024 * 1024
local lines_cache, lines_cached = {}, 0

local function lines_of(file)
	-- `cha` follows symlinks, so only resolved regular files are safe and meaningful to count.
	local perm = file.cha:perm()
	if not perm or perm:sub(1, 1) ~= "-" then
		return nil
	end

	local len = file.cha.len or 0
	if len == 0 then
		return 0
	elseif len > LINES_CAP then
		return nil
	end

	local path = tostring(file.url)
	local key = string.format("%d\0%s\0%s", len, file.cha.mtime or 0, path)

	-- `false` caches binary files too, preventing a new process on every status redraw.
	local hit = lines_cache[key]
	if hit == nil then
		-- Quote the path for /bin/sh so unusual filenames remain one grep argument.
		local quoted = path:gsub("'", "'\\''")
		local proc = io.popen("grep -Ic '' '" .. quoted .. "' 2>/dev/null")
		local out = proc:read("a")
		hit = proc:close() and tonumber(out) or false

		if lines_cached >= 512 then
			lines_cache, lines_cached = {}, 0
		end
		lines_cache[key], lines_cached = hit, lines_cached + 1
	end

	return hit or nil
end

return {
	setup = function()
		Status:children_add(function(self)
			local hovered = self._current.hovered
			if not hovered then
				return ""
			end

			local lines = lines_of(hovered)
			if not lines then
				return ""
			end

			return ui.Line({ ui.Span(string.format(" %dL", lines)):fg("darkgray") })
		end, 2500, Status.LEFT)
	end,
}
