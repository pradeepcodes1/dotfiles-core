-- derive lualine colors from imported Gogh palettes so unknown themes stay coherent.
local palette, theme = require("core.theme").get_palette()
palette = palette or {}
theme = theme or {}
local colors = require("core.palette")
local blend = colors.blend
local rgb = colors.rgb

local function color(name, fallback)
	return colors.pick(palette, name, fallback)
end

local bg = color("bg", "black")
local fg = color("fg", "bright_white")
local mode = theme.background or theme.mode
if mode ~= "dark" and mode ~= "light" then
	mode = "dark"
end

local function relative_luminance(hex)
	local red, green, blue = rgb(hex)
	local function linear(channel)
		channel = channel / 255
		return channel <= 0.04045 and channel / 12.92 or ((channel + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
end

local function contrast(left, right)
	local left_luminance = relative_luminance(left)
	local right_luminance = relative_luminance(right)
	local lighter = math.max(left_luminance, right_luminance)
	local darker = math.min(left_luminance, right_luminance)
	return (lighter + 0.05) / (darker + 0.05)
end

local function mode_foreground(accent)
	return contrast(bg, accent) >= contrast(fg, accent) and bg or fg
end

local section_bg = blend(fg, bg, mode == "dark" and 0.08 or 0.06)
local section_alt = blend(fg, bg, mode == "dark" and 0.14 or 0.1)
local inactive_fg = palette.prompt_path or color("bright_black", "black")
local accents = {
	normal = palette.ui_accent or palette.ui_active or color("bright_blue", "blue"),
	insert = color(mode == "dark" and "bright_green" or "green", "green"),
	visual = color(mode == "dark" and "bright_magenta" or "magenta", "magenta"),
	replace = color(mode == "dark" and "bright_red" or "red", "red"),
	command = color(mode == "dark" and "bright_yellow" or "yellow", "yellow"),
	terminal = color(mode == "dark" and "bright_cyan" or "cyan", "cyan"),
}

local function active(accent)
	return {
		a = { fg = mode_foreground(accent), bg = accent, gui = "bold" },
		b = { fg = accent, bg = section_alt },
		c = { fg = fg, bg = section_bg },
	}
end

return {
	normal = active(accents.normal),
	insert = active(accents.insert),
	visual = active(accents.visual),
	replace = active(accents.replace),
	command = active(accents.command),
	terminal = active(accents.terminal),
	inactive = {
		a = { fg = inactive_fg, bg = section_bg },
		b = { fg = inactive_fg, bg = section_bg },
		c = { fg = inactive_fg, bg = bg },
	},
}
