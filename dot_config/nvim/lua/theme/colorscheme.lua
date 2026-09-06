-- render imported Gogh palettes through mini.base16's highlight set.
--
-- A Gogh theme is an ANSI palette -- a background, a foreground and 16 colors --
-- which is what base16 is, so the whole colorscheme is a mapping between the
-- two plus mini.base16. That covers builtin groups, Treesitter, LSP semantic
-- tokens and a long list of plugins, in place of the ~450 hand-written groups
-- this file used to carry.
local theme = require("theme").current()
local blend = require("theme.palette").blend
local p = theme.palette
local syntax = theme.syntax
local accent = theme.accents.normal
local comment = theme.comment

vim.o.background = theme.mode

require("mini.base16").setup({
	palette = {
		base00 = p.bg, -- default background
		base01 = theme.surface, -- float and status backgrounds
		base02 = theme.surface_high, -- selection background
		base03 = comment, -- comments, invisibles
		base04 = p.white, -- dim foreground
		base05 = p.fg, -- default foreground
		base06 = p.bright_white, -- bright foreground
		base07 = p.bright_white, -- brightest background
		base08 = syntax.red, -- variables, errors
		-- base09 is base16's orange, which ANSI has no slot for; mixing red
		-- and yellow is closer than reusing either, and keeps base09 and
		-- base0A distinguishable the way base16 groups expect.
		base09 = blend(syntax.red, syntax.yellow, 0.5), -- numbers, constants
		base0A = syntax.yellow, -- classes, types
		base0B = syntax.green, -- strings
		base0C = syntax.cyan, -- escapes, regex, support
		base0D = syntax.blue, -- functions
		base0E = syntax.magenta, -- keywords
		base0F = blend(syntax.red, syntax.magenta, 0.5), -- deprecated
	},
})

-- mini.base16 clears colors_name so `syntax on` behaves; this is a colorscheme
-- file, so put it back or :colorscheme has nothing to report.
vim.g.colors_name = "dotfiles-gogh"

for index, color in ipairs({
	p.black,
	p.red,
	p.green,
	p.yellow,
	p.blue,
	p.magenta,
	p.cyan,
	p.white,
	p.bright_black,
	p.bright_red,
	p.bright_green,
	p.bright_yellow,
	p.bright_blue,
	p.bright_magenta,
	p.bright_cyan,
	p.bright_white,
}) do
	vim.g["terminal_color_" .. (index - 1)] = color
end

local inactive = theme.inactive

-- Deliberate departures from the base16 spec, which mini.base16 follows
-- faithfully. base08 is "variables" there, so Identifier -- and every group
-- linked to it -- comes out red, and base0F puts brackets and separators in
-- the deprecated-token color. Both are louder than this config wants: code
-- should be foreground-colored by default, with color reserved for the parts
-- that carry meaning.
--
-- Plugin groups follow, for the plugins mini.base16 has no integration with.
-- Everything else it either sets directly or reaches by a default link.
for name, spec in pairs({
	Comment = { fg = comment, italic = true },
	Delimiter = { fg = comment },
	Directory = { fg = syntax.blue, bold = true },
	Identifier = { fg = p.fg },
	Keyword = { fg = syntax.magenta, italic = true },
	["@property"] = { fg = syntax.cyan },
	["@variable.member"] = { fg = syntax.cyan },
	["@variable.parameter"] = { fg = p.fg, italic = true },

	AerialClassIcon = { fg = syntax.yellow },
	AerialFunctionIcon = { fg = syntax.blue },
	AerialGuide = { fg = inactive },
	AerialLine = { link = "Visual" },
	AerialMethodIcon = { fg = syntax.blue },
	AerialVariableIcon = { fg = syntax.cyan },

	-- dap-ui is covered; these are nvim-dap's own sign-column groups.
	DapBreakpoint = { fg = syntax.red },
	DapBreakpointCondition = { fg = syntax.yellow },
	DapStopped = { fg = syntax.green, bg = blend(syntax.green, p.bg, 0.18) },

	SnacksDashboardDesc = { fg = p.fg },
	SnacksDashboardFooter = { fg = comment, italic = true },
	SnacksDashboardHeader = { fg = accent },
	SnacksDashboardIcon = { fg = syntax.cyan },
	SnacksDashboardKey = { fg = syntax.yellow, bold = true },
	SnacksDashboardSpecial = { fg = syntax.magenta },
	-- Keep directory paths readable without overriding the picker background.
	SnacksPickerDir = { fg = p.fg },
	SnacksPickerListCursorLine = { link = "Visual" },
	SnacksPickerMatch = { fg = syntax.yellow, bold = true },
	-- Left to itself this links to Search, whose base16 foreground is base01 --
	-- the very color CursorLine uses as its background. In the preview the
	-- selected row's cursorline (SnacksPickerPreviewCursorLine -> Visual,
	-- base02) paints over Search's yellow background, leaving base01 text on
	-- base02: two blends of the same pair, 5.5% apart, and the match vanishes
	-- on exactly the row being previewed. Match the list-side group instead --
	-- a foreground with no background survives whatever the cursorline paints.
	SnacksPickerSearch = { fg = syntax.yellow, bold = true },

	TodoBgFIX = { fg = p.bg, bg = syntax.red, bold = true },
	TodoBgNOTE = { fg = p.bg, bg = syntax.cyan, bold = true },
	TodoBgTODO = { fg = p.bg, bg = syntax.blue, bold = true },
	TodoBgWARN = { fg = p.bg, bg = syntax.yellow, bold = true },
	TodoFgFIX = { fg = syntax.red, bold = true },
	TodoFgNOTE = { fg = syntax.cyan, bold = true },
	TodoFgTODO = { fg = syntax.blue, bold = true },
	TodoFgWARN = { fg = syntax.yellow, bold = true },
}) do
	vim.api.nvim_set_hl(0, name, spec)
end
