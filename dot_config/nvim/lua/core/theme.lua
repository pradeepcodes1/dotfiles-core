-- read the shell's persisted theme so Neovim and terminal tools switch together.
local M = {}
local palette = require("core.palette")
local current

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

	line = vim.trim(line)
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

local function gogh_themes_dir()
	local data_home = vim.env.XDG_DATA_HOME or "~/.local/share"
	return vim.fs.joinpath(expand(data_home), "dotfiles", "gogh", "themes")
end

local function read_theme_name()
	return read_first_line(state_file())
end

local function find_theme_path(theme_name)
	local path = vim.fs.joinpath(gogh_themes_dir(), theme_name .. ".sh")
	local file = io.open(path, "r")
	if file then
		return file, path, "gogh"
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
		line = vim.trim(line)

		theme.mode = theme.mode or line:match("^# Mode:%s*(%S+)$")

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
		return palette.resolve({
			name = parsed.name,
			path = parsed.path,
			source = parsed.source,
			mode = parsed.mode or vim.env._DOTFILES_THEME_MODE,
			colorscheme = parsed.colorscheme or "dotfiles-gogh",
			lualine = parsed.lualine or "dotfiles-gogh",
			background = parsed.background,
			palette = parsed.palette,
		})
	end

	return palette.resolve({
		name = vim.env._DOTFILES_THEME_NAME,
		mode = vim.env._DOTFILES_THEME_MODE,
		colorscheme = vim.env._DOTFILES_NVIM_COLORSCHEME or "dotfiles-gogh",
		lualine = vim.env._DOTFILES_NVIM_LUALINE or "dotfiles-gogh",
		background = vim.env._DOTFILES_NVIM_BACKGROUND,
		palette = nil,
	})
end

function M.current()
	if not current then
		current = M.resolve()
	end
	return current
end

local function publish(theme)
	vim.env._DOTFILES_THEME_NAME = theme.name
	vim.env._DOTFILES_THEME_MODE = theme.mode
	vim.env._DOTFILES_NVIM_COLORSCHEME = theme.colorscheme
	vim.env._DOTFILES_NVIM_LUALINE = theme.lualine
	vim.env._DOTFILES_NVIM_BACKGROUND = theme.background
	vim.g.dotfiles_theme_name = theme.name
	vim.g.dotfiles_theme_path = theme.path
	vim.g.dotfiles_theme_palette = theme.raw_palette
	current = theme

	return theme
end

-- Resolve once before plugins load so early consumers (notably lualine) see
-- the same snapshot that the colorscheme application will use.
function M.prepare()
	return publish(M.resolve())
end

-- Kept as a compatibility alias for config outside this repository.
function M.sync_env_from_state()
	return M.prepare()
end

function M.get_palette()
	-- The return shape is intentionally unchanged for external consumers;
	-- repository code consumes current() directly.
	local theme = M.current()
	return vim.deepcopy(theme.raw_palette), theme
end

function M.apply(theme)
	theme = publish(theme or M.resolve())
	vim.o.background = theme.mode
	vim.cmd.colorscheme(theme.colorscheme)
	vim.api.nvim_exec_autocmds("User", {
		pattern = "DotfilesThemeChanged",
		data = { theme = theme },
	})

	return theme
end

-- Re-read the persisted state and reapply it to a session that's already
-- running (e.g. a Noctalia theme change broadcast via `nvim --server`).
function M.reapply()
	return M.apply(M.resolve())
end

vim.api.nvim_create_user_command("DotfilesThemeReload", M.reapply, {
	desc = "Reapply the persisted dotfiles theme (colorscheme + lualine)",
})

return M
