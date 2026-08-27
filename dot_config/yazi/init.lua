-- load Git status data used by the configured fetchers and file-list columns.
require("git"):setup()

-- Keep the useful size column while also showing Unix file permissions.
function Linemode:size_permissions()
	local size = self._file:size()
	local permissions = self._file.cha:perm()

	return string.format("%s %s", permissions or "----------", size and ya.readable_size(size) or "-")
end
