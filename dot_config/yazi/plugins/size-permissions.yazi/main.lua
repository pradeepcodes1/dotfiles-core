-- Yazi loads these plugins into its own Lua runtime, where `ya`, `ui`, `cx`,
-- `Status` and `Linemode` are supplied as globals. lua_ls indexes this repo as
-- one Neovim workspace, so nothing here can declare them -- a `.luarc.json`
-- beside this file only applies when lua_ls happens to root itself here rather
-- than at the repo, which it does not once a Neovim buffer opened first.
---@diagnostic disable: undefined-global

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
