-- load Git status data used by the configured fetchers and file-list columns.
require("git"):setup()

-- Keep the useful size column while also showing Unix file permissions.
function Linemode:size_permissions()
	local size = self._file:size()
	local permissions = self._file.cha:perm()

	return string.format("%s %s", permissions or "----------", size and ya.readable_size(size) or "-")
end

-- Line count of the hovered file, shown in the status bar between the size and
-- the name. `grep -Ic ""` counts lines the way an editor does, including a last
-- line with no trailing newline that `wc -l` would miss, and refuses to read
-- binary files, so images and archives show no count instead of a meaningless
-- one. It reports that refusal only in its exit status -- it still prints a "0"
-- indistinguishable from a genuinely empty file -- so the status decides.
--
-- Yazi has no async hook that runs for the hovered file alone -- a fetcher would
-- read every file in the directory -- so this shells out synchronously inside the
-- status redraw. Caching per (size, mtime, path) keeps that to one spawn per
-- file rather than one per frame, and files above the cap are skipped entirely.
local LINES_CAP = 2 * 1024 * 1024
local lines_cache, lines_cached = {}, 0

local function lines_of(file)
	-- `cha` follows symlinks, so the leading character of the permission string is
	-- the resolved file type. Anything but a regular file is either meaningless to
	-- count (a directory) or unsafe to read (a FIFO blocks until a writer appears).
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

	-- `false` marks a file that was tried and has no count, so a binary file is not
	-- respawned on every redraw.
	local hit = lines_cache[key]
	if hit == nil then
		-- io.popen goes through /bin/sh -- Yazi's own Command API is async, so it
		-- cannot be called while rendering. Single-quote the path and escape any
		-- embedded quote so odd filenames stay a single argument.
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
