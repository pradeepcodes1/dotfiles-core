-- Build lualine colors from the same resolved snapshot as the colorscheme.
local M = {}

function M.build(theme)
	local p = theme.palette

	local function active(name)
		local accent = theme.accents[name]
		return {
			a = { fg = theme.accent_foregrounds[name], bg = accent, gui = "bold" },
			b = { fg = accent, bg = theme.section_alt },
			c = { fg = p.fg, bg = theme.section_bg },
		}
	end

	return {
		normal = active("normal"),
		insert = active("insert"),
		visual = active("visual"),
		replace = active("replace"),
		command = active("command"),
		terminal = active("terminal"),
		inactive = {
			a = { fg = theme.comment, bg = theme.section_bg },
			b = { fg = theme.comment, bg = theme.section_bg },
			c = { fg = theme.comment, bg = p.bg },
		},
	}
end

return M
