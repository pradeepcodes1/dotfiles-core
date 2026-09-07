-- Keep the custom linemode isolated from unrelated Yazi startup wiring.
return {
	setup = function()
		function Linemode:size_permissions()
			local size = self._file:size()
			local permissions = self._file.cha:perm()

			return string.format("%s %s", permissions or "----------", size and ya.readable_size(size) or "-")
		end
	end,
}
