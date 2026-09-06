-- Normalize terminal palettes and derive shared theme color roles.
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

local ansi_keys = {
	"bg",
	"fg",
	"black",
	"red",
	"green",
	"yellow",
	"blue",
	"magenta",
	"cyan",
	"white",
	"bright_black",
	"bright_red",
	"bright_green",
	"bright_yellow",
	"bright_blue",
	"bright_magenta",
	"bright_cyan",
	"bright_white",
}

local fallbacks = {
	bg = "ui_bg",
	fg = "ui_fg",
	black = "bg",
	red = "bright_red",
	green = "bright_green",
	yellow = "bright_yellow",
	blue = "bright_blue",
	magenta = "bright_magenta",
	cyan = "bright_cyan",
	white = "fg",
	bright_black = "black",
	bright_red = "red",
	bright_green = "green",
	bright_yellow = "yellow",
	bright_blue = "blue",
	bright_magenta = "magenta",
	bright_cyan = "cyan",
	bright_white = "white",
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

local function relative_luminance(hex)
	local red, green, blue = M.rgb(hex)
	local function linear(channel)
		channel = channel / 255
		return channel <= 0.04045 and channel / 12.92 or ((channel + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
end

function M.contrast(left, right)
	local left_luminance = relative_luminance(left)
	local right_luminance = relative_luminance(right)
	local lighter = math.max(left_luminance, right_luminance)
	local darker = math.min(left_luminance, right_luminance)
	return (lighter + 0.05) / (darker + 0.05)
end

local function resolve_mode(requested, bg)
	if requested == "dark" or requested == "light" then
		return requested
	end

	local red, green, blue = M.rgb(bg)
	local brightness = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
	return brightness > 0.55 and "light" or "dark"
end

local function best_foreground(bg, fg, accent)
	return M.contrast(bg, accent) >= M.contrast(fg, accent) and bg or fg
end

-- Turn a possibly incomplete Gogh palette into the one snapshot every theme
-- consumer uses. Metadata is copied through so callers can publish it without
-- retaining a second, partially resolved representation.
function M.resolve(theme)
	theme = theme or {}
	local raw = theme.palette or {}
	local colors = {}

	for _, name in ipairs(ansi_keys) do
		colors[name] = M.pick(raw, name, fallbacks[name])
	end

	-- UI aliases may be the only foreground/background supplied by an older
	-- generated theme, so honor them before falling back to the complete base.
	colors.bg = raw.bg or raw.ui_bg or M.defaults.bg
	colors.fg = raw.fg or raw.ui_fg or M.defaults.fg

	local mode = resolve_mode(theme.background or theme.mode, colors.bg)
	local syntax = {}
	for _, name in ipairs({ "red", "green", "yellow", "blue", "magenta", "cyan" }) do
		syntax[name] = colors[mode == "dark" and ("bright_" .. name) or name]
	end

	local accents = {
		normal = raw.ui_accent or raw.ui_active or syntax.blue,
		insert = syntax.green,
		visual = syntax.magenta,
		replace = syntax.red,
		command = syntax.yellow,
		terminal = syntax.cyan,
	}

	local resolved = {
		name = theme.name,
		path = theme.path,
		source = theme.source,
		colorscheme = theme.colorscheme or "dotfiles-gogh",
		lualine = theme.lualine or "dotfiles-gogh",
		mode = mode,
		background = mode,
		palette = colors,
		raw_palette = theme.palette,
		syntax = syntax,
		accents = accents,
		comment = raw.prompt_path or colors.bright_black,
		surface = M.blend(colors.fg, colors.bg, 0.055),
		surface_high = M.blend(colors.fg, colors.bg, 0.11),
		inactive = raw.ui_inactive or M.blend(colors.fg, colors.bg, 0.09),
		section_bg = M.blend(colors.fg, colors.bg, mode == "dark" and 0.08 or 0.06),
		section_alt = M.blend(colors.fg, colors.bg, mode == "dark" and 0.14 or 0.1),
	}

	resolved.accent_foregrounds = {}
	for name, accent in pairs(accents) do
		resolved.accent_foregrounds[name] = best_foreground(colors.bg, colors.fg, accent)
	end

	return resolved
end

return M
