-- read the shell's persisted theme so Neovim and terminal tools switch together.
local M = {}

local palette_keys = {
	bg = true,
	fg = true,
	black = true,
	red = true,
	green = true,
	yellow = true,
	blue = true,
	magenta = true,
	cyan = true,
	white = true,
	bright_black = true,
	bright_red = true,
	bright_green = true,
	bright_yellow = true,
	bright_blue = true,
	bright_magenta = true,
	bright_cyan = true,
	bright_white = true,
	prompt_dir = true,
	prompt_branch = true,
	prompt_unstaged = true,
	prompt_staged = true,
	prompt_arrow = true,
	prompt_path = true,
	ui_bg = true,
	ui_fg = true,
	ui_accent = true,
	ui_border = true,
	ui_active = true,
	ui_inactive = true,
}

local function expand(path)
	return vim.fn.expand(path)
end

local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

local function read_first_line(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local line = file:read("*l")
	file:close()
	if not line then
		return nil
	end

	line = trim(line)
	if line == "" then
		return nil
	end

	return line
end

local function parse_assignment(line, name)
	local value = line:match("^" .. name .. "%s*=%s*['\"](.-)['\"]$")
	if value and value ~= "" then
		return value
	end
	return nil
end

local function parse_palette_assignment(line)
	local name, value = line:match("^([%a_][%w_]*)%s*=%s*['\"](#%x%x%x%x%x%x)['\"]$")
	if name and palette_keys[name] then
		return name, value:lower()
	end
	return nil, nil
end

local function state_file()
	local state_home = vim.env.XDG_STATE_HOME or "~/.local/state"
	return vim.fs.joinpath(expand(state_home), "dotfiles", "theme")
end

local function colors_dir()
	return vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "colors")
end

local function gogh_themes_dir()
	local data_home = vim.env.XDG_DATA_HOME or "~/.local/share"
	return vim.fs.joinpath(expand(data_home), "dotfiles", "gogh", "themes")
end

local function read_theme_name()
	return read_first_line(state_file())
end

local function find_theme_path(theme_name)
	local candidates = {
		{ path = vim.fs.joinpath(colors_dir(), theme_name .. ".sh"), source = "curated" },
		{ path = vim.fs.joinpath(gogh_themes_dir(), theme_name .. ".sh"), source = "gogh" },
	}

	for _, candidate in ipairs(candidates) do
		local file = io.open(candidate.path, "r")
		if file then
			return file, candidate.path, candidate.source
		end
	end

	return nil, nil, nil
end

local function parse_theme(theme_name)
	local file, path, source = find_theme_path(theme_name)
	if not file then
		return nil
	end

	local theme = {
		name = theme_name,
		path = path,
		source = source,
		palette = {},
	}

	for line in file:lines() do
		line = trim(line)

		theme.mode = theme.mode or line:match("^# Mode:%s*(%S+)$")

		local transparent = line:match("^# Transparent:%s*([01])$")
		if transparent then
			theme.transparent = transparent == "1"
		end

		theme.colorscheme = theme.colorscheme or parse_assignment(line, "nvim_colorscheme")
		theme.lualine = theme.lualine or parse_assignment(line, "nvim_lualine")
		theme.background = theme.background or parse_assignment(line, "nvim_background")

		local name, value = parse_palette_assignment(line)
		if name then
			theme.palette[name] = value
		end
	end

	file:close()
	if not next(theme.palette) then
		theme.palette = nil
	end

	return theme
end

function M.resolve()
	local theme_name = read_theme_name()
	local parsed = theme_name and parse_theme(theme_name) or nil

	if parsed then
		return {
			name = parsed.name,
			path = parsed.path,
			source = parsed.source,
			mode = parsed.mode or vim.env._DOTFILES_THEME_MODE,
			transparent = parsed.transparent == true,
			colorscheme = parsed.colorscheme or "kanagawa-dragon",
			lualine = parsed.lualine or "codedark",
			background = parsed.background or (parsed.colorscheme == "dotfiles-gogh" and parsed.mode or nil),
			palette = parsed.palette,
		}
	end

	return {
		name = vim.env._DOTFILES_THEME_NAME,
		mode = vim.env._DOTFILES_THEME_MODE,
		transparent = vim.env._DOTFILES_THEME_TRANSPARENT == "1",
		colorscheme = vim.env._DOTFILES_NVIM_COLORSCHEME or "kanagawa-dragon",
		lualine = vim.env._DOTFILES_NVIM_LUALINE or "codedark",
		background = vim.env._DOTFILES_NVIM_BACKGROUND,
		palette = nil,
	}
end

function M.get_palette()
	local theme = M.resolve()
	return vim.deepcopy(theme.palette), theme
end

function M.sync_env_from_state()
	local theme = M.resolve()

	if theme.name then
		vim.env._DOTFILES_THEME_NAME = theme.name
	end
	if theme.mode then
		vim.env._DOTFILES_THEME_MODE = theme.mode
	end

	vim.env._DOTFILES_THEME_TRANSPARENT = theme.transparent and "1" or "0"
	vim.env._DOTFILES_NVIM_COLORSCHEME = theme.colorscheme
	vim.env._DOTFILES_NVIM_LUALINE = theme.lualine

	vim.env._DOTFILES_NVIM_BACKGROUND = theme.background
	vim.g.dotfiles_theme_name = theme.name
	vim.g.dotfiles_theme_path = theme.path
	vim.g.dotfiles_theme_palette = theme.palette

	return theme
end

return M
