-- share terminal-palette fallbacks and color math across generated themes.
local M = {}

M.defaults = {
	bg = "#1e1e2e",
	fg = "#cdd6f4",
	black = "#45475a",
	red = "#f38ba8",
	green = "#a6e3a1",
	yellow = "#f9e2af",
	blue = "#89b4fa",
	magenta = "#cba6f7",
	cyan = "#94e2d5",
	white = "#bac2de",
	bright_black = "#585b70",
	bright_red = "#f38ba8",
	bright_green = "#a6e3a1",
	bright_yellow = "#f9e2af",
	bright_blue = "#89b4fa",
	bright_magenta = "#cba6f7",
	bright_cyan = "#94e2d5",
	bright_white = "#a6adc8",
}

function M.pick(palette, name, fallback)
	return palette[name] or palette[fallback] or M.defaults[name] or M.defaults[fallback]
end

function M.rgb(hex)
	return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

function M.blend(foreground, background, amount)
	local fr, fg, fb = M.rgb(foreground)
	local br, bg, bb = M.rgb(background)
	local function channel(front, back)
		return math.floor(front * amount + back * (1 - amount) + 0.5)
	end
	return string.format("#%02x%02x%02x", channel(fr, br), channel(fg, bg), channel(fb, bb))
end

return M
