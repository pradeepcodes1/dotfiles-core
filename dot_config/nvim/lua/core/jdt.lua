-- normalize jdt:// buffers so Java navigation and buffer labels remain readable.
local M = {}

M.JAVA_ICON = "\xee\x9c\xb8" -- nf-md-language_java (U+E738)

--- Check if a buffer name is a jdt:// virtual URI.
function M.is_jdt(bufname)
	return bufname:match("^jdt://") ~= nil
end

--- Strip query string from a jdt:// URI and return the path portion.
local function strip_jdt_path(uri)
	return uri:match("^jdt://(.-)%?") or uri:match("^jdt://(.*)")
end

--- Extract class name from a jdt:// URI, returned as "ClassName.java".
function M.classname(uri)
	local path = strip_jdt_path(uri)
	if not path then
		return nil
	end
	local name = path:match("([^/]+)%.class$")
	return name and (name .. ".java") or nil
end

--- Extract fully qualified name from a jdt:// URI (e.g. "java.util.HashMap").
function M.fqcn(uri)
	local path = strip_jdt_path(uri)
	if not path then
		return nil
	end
	local segments = {}
	for seg in path:gmatch("[^/]+") do
		segments[#segments + 1] = seg
	end
	if #segments >= 3 then
		local pkg = segments[#segments - 1]
		local cls = segments[#segments]:gsub("%.class$", "")
		return pkg .. "." .. cls
	end
	return segments[#segments] and segments[#segments]:gsub("%.class$", "") or nil
end

return M
