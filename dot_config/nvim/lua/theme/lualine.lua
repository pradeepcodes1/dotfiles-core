-- Build lualine colors from the resolved theme snapshot.
local M = {}

function M.build(theme)
	local p = theme.palette

	local function active(name)
		local accent = theme.accents[name]
		return {
			a = { fg = theme.accent_foregrounds[name], bg = accent, gui = "bold" },
			-- Only the mode badge carries a saturated background.
			b = { fg = p.fg, bg = theme.section_bg },
			c = { fg = p.fg, bg = theme.section_bg },
		}
	end

	local result = {
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
	-- Lualine otherwise mirrors the mode badge onto the right-hand position block.
	for _, sections in pairs(result) do
		sections.x = { fg = p.fg, bg = theme.section_bg }
		sections.y = { fg = theme.muted, bg = theme.section_bg }
		sections.z = { fg = theme.muted, bg = theme.section_bg }
	end
	return result
end

return M
