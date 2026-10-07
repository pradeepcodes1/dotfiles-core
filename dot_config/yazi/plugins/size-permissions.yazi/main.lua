-- Yazi loads these plugins into its own Lua runtime, where `ya`, `ui`, `cx`,
-- `Status`, `Current` and `Linemode` are supplied as globals. lua_ls indexes this repo as
-- one Neovim workspace, so nothing here can declare them -- a `.luarc.json`
-- beside this file only applies when lua_ls happens to root itself here rather
-- than at the repo, which it does not once a Neovim buffer opened first.
---@diagnostic disable: undefined-global

-- Below these center-pane widths, the linemode sheds perms and then size,
-- so long filenames keep the columns instead of truncating early.
local PERMS_MIN_PANE_W = 50
local SIZE_MIN_PANE_W = 30
-- The status bar spans the whole terminal; hide its perms on narrow windows.
local STATUS_PERMS_MIN_W = 80

-- Linemode is built per row without an area, so remember the width that
-- `Current:redraw` is about to lay those rows into. Starts wide so a changed
-- upstream `Current` falls back to the full column rather than hiding it.
local pane_w = math.huge

-- Keep the custom linemode isolated from unrelated Yazi startup wiring.
return {
	setup = function()
		local current_redraw = Current.redraw
		function Current:redraw()
			pane_w = self._area.w
			return current_redraw(self)
		end

		function Linemode:size_permissions()
			if pane_w < SIZE_MIN_PANE_W then
				return ""
			end

			local size = self._file:size()
			local readable = size and ya.readable_size(size) or "-"
			if pane_w < PERMS_MIN_PANE_W then
				return readable
			end

			return string.format("%s %s", self._file.cha:perm() or "----------", readable)
		end

		-- Status already knows its own width, so gate the built-in perm child directly.
		local status_perm = Status.perm
		function Status:perm()
			if self._area.w < STATUS_PERMS_MIN_W then
				return ""
			end
			return status_perm(self)
		end
	end,
}
