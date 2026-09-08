-- render imported Gogh palettes through mini.base16's highlight set.
--
-- Keep terminal colors intact while mapping derived editor roles onto base16.
-- mini.base16 supplies broad coverage; the overrides below share UI semantics.
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
		base02 = theme.selection, -- selection background
		base03 = comment, -- comments, invisibles
		base04 = theme.muted, -- dim foreground
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

-- Give syntax and plugin UI explicit roles beyond the base16 defaults.
for name, spec in pairs({
	-- Keep gutters quiet and distinguish floating surfaces from cursor and selection states.
	NormalFloat = { fg = p.fg, bg = theme.surface },
	FloatBorder = { fg = theme.border, bg = theme.surface },
	FloatTitle = { fg = accent, bg = theme.surface, bold = true },
	WinSeparator = { fg = theme.border, bg = p.bg },
	VertSplit = { link = "WinSeparator" },
	CursorLine = { bg = theme.cursorline },
	CursorColumn = { link = "CursorLine" },
	LineNr = { fg = theme.muted, bg = p.bg },
	LineNrAbove = { link = "LineNr" },
	LineNrBelow = { link = "LineNr" },
	CursorLineNr = { fg = accent, bg = theme.cursorline, bold = true },
	SignColumn = { bg = p.bg },
	FoldColumn = { fg = theme.muted, bg = p.bg },
	NonText = { fg = theme.guide },
	Whitespace = { link = "NonText" },
	SpecialKey = { link = "NonText" },
	EndOfBuffer = { fg = p.bg },
	Visual = { fg = theme.selection_fg, bg = theme.selection },
	Pmenu = { link = "NormalFloat" },
	PmenuSel = { link = "Visual" },
	PmenuThumb = { bg = theme.border },
	QuickFixLine = { link = "Visual" },
	MatchParen = { fg = accent, bg = theme.surface_high, bold = true },
	-- Keep comments upright so GUI and terminal renderers use a consistent shape.
	Comment = { fg = comment, italic = false },
	Delimiter = { fg = theme.muted },
	Directory = { fg = theme.muted },
	-- Symbols keep semantic colors in both Treesitter and higher-priority LSP tokens.
	Identifier = { fg = syntax.red },
	Keyword = { fg = syntax.magenta },
	["@variable"] = { fg = syntax.red },
	["@variable.builtin"] = { fg = syntax.magenta },
	["@property"] = { fg = syntax.cyan },
	["@variable.member"] = { link = "@property" },
	["@variable.parameter"] = { fg = syntax.yellow },
	["@function"] = { fg = syntax.blue },
	["@function.method"] = { link = "@function" },
	["@type"] = { fg = syntax.yellow },
	["@module"] = { fg = syntax.cyan },
	["@lsp.type.variable"] = { link = "@variable" },
	["@lsp.type.property"] = { link = "@property" },
	["@lsp.type.parameter"] = { link = "@variable.parameter" },
	["@lsp.type.function"] = { link = "@function" },
	["@lsp.type.method"] = { link = "@function.method" },
	["@lsp.type.class"] = { link = "@type" },
	["@lsp.type.interface"] = { link = "@type" },
	["@lsp.type.struct"] = { link = "@type" },
	["@lsp.type.enum"] = { link = "@type" },
	["@lsp.type.namespace"] = { link = "@module" },
	["@punctuation.bracket"] = { fg = theme.muted },
	["@punctuation.delimiter"] = { fg = theme.muted },
	Operator = { fg = theme.muted },

	-- Plugin defaults inherit these shared surfaces, borders, and selected-row colors.
	BlinkCmpMenuBorder = { link = "FloatBorder" },
	BlinkCmpDocBorder = { link = "FloatBorder" },
	BlinkCmpSignatureHelpBorder = { link = "FloatBorder" },
	BlinkCmpDocSeparator = { fg = theme.border, bg = theme.surface },
	-- Pickers also host the docked explorer, which should not become a bright slab.
	-- Snacks maps NormalFloat to the bare prefix, not SnacksPickerNormal.
	SnacksPicker = { fg = p.fg, bg = p.bg },
	SnacksPickerInput = { link = "SnacksPicker" },
	SnacksPickerList = { link = "SnacksPicker" },
	SnacksPickerPreview = { link = "SnacksPicker" },
	SnacksPickerBox = { link = "SnacksPicker" },
	SnacksPickerBorder = { fg = theme.guide, bg = p.bg },
	SnacksPickerTree = { fg = theme.guide },
	SnacksPickerDirectory = { fg = p.fg },
	SnacksPickerPathIgnored = { fg = comment },
	SnacksPickerPathHidden = { fg = theme.muted },
	SnacksPickerWinBar = { fg = theme.muted, bg = p.bg },
	SnacksPickerTitle = { fg = theme.muted, bg = p.bg },
	SnacksIndent = { fg = theme.guide },
	SnacksIndentScope = { fg = theme.border },
	DapUIFloatBorder = { link = "FloatBorder" },
	-- FFF's panes and border share the editor background instead of the raised float surface.
	DotfilesPickerNormal = { fg = p.fg, bg = p.bg },
	DotfilesPickerBorder = { fg = theme.border, bg = p.bg },
	DotfilesPickerTitle = { fg = accent, bg = p.bg, bold = true },
	DotfilesPickerMatch = { fg = syntax.yellow, bold = true },

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
	SnacksDashboardFooter = { fg = comment, italic = false },
	SnacksDashboardHeader = { fg = accent },
	SnacksDashboardIcon = { fg = syntax.cyan },
	SnacksDashboardKey = { fg = syntax.yellow, bold = true },
	SnacksDashboardSpecial = { fg = syntax.magenta },
	-- Keep directory paths readable without overriding the picker background.
	SnacksPickerDir = { fg = p.fg },
	SnacksPickerListCursorLine = { link = "Visual" },
	-- Match colors distinguish project results without changing their font weight.
	SnacksPickerMatch = { fg = syntax.yellow, bold = false },
	SnacksPickerBold = { fg = p.fg, bold = false },
	-- Left to itself this links to Search, whose base16 foreground is base01 --
	-- the very color CursorLine uses as its background. In the preview the
	-- selected row's cursorline (SnacksPickerPreviewCursorLine -> Visual,
	-- base02) paints over Search's yellow background, leaving base01 text on
	-- base02: two blends of the same pair, 5.5% apart, and the match vanishes
	-- on exactly the row being previewed. Match the list-side group instead --
	-- a foreground with no background survives whatever the cursorline paints.
	SnacksPickerSearch = { fg = syntax.yellow, bold = true },

	TodoBgFIX = { fg = theme.accent_foregrounds.replace, bg = syntax.red, bold = true },
	TodoBgNOTE = { fg = theme.accent_foregrounds.terminal, bg = syntax.cyan, bold = true },
	TodoBgTODO = {
		fg = require("theme.palette").ensure_contrast(p.bg, syntax.blue, 4.5),
		bg = syntax.blue,
		bold = true,
	},
	TodoBgWARN = { fg = theme.accent_foregrounds.command, bg = syntax.yellow, bold = true },
	TodoFgFIX = { fg = syntax.red, bold = true },
	TodoFgNOTE = { fg = syntax.cyan, bold = true },
	TodoFgTODO = { fg = syntax.blue, bold = true },
	TodoFgWARN = { fg = syntax.yellow, bold = true },
}) do
	vim.api.nvim_set_hl(0, name, spec)
end

-- Diagnostics use the same severity colors in text, signs, floats, and underlines.
for severity, color in pairs({
	Error = syntax.red,
	Warn = syntax.yellow,
	Info = syntax.cyan,
	Hint = syntax.blue,
	Ok = syntax.green,
}) do
	vim.api.nvim_set_hl(0, "Diagnostic" .. severity, { fg = color })
	vim.api.nvim_set_hl(0, "DiagnosticSign" .. severity, { fg = color })
	vim.api.nvim_set_hl(0, "DiagnosticFloating" .. severity, { fg = color, bg = theme.surface })
	vim.api.nvim_set_hl(0, "DiagnosticVirtualText" .. severity, { fg = color })
	vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. severity, { undercurl = true, sp = color })
end
vim.api.nvim_set_hl(0, "WarningMsg", { link = "DiagnosticWarn" })

-- Tinted diff backgrounds communicate changes without replacing syntax colors.
for name, spec in pairs({
	DiffAdd = { bg = blend(syntax.green, p.bg, 0.12) },
	DiffChange = { bg = blend(syntax.blue, p.bg, 0.10) },
	DiffDelete = { fg = syntax.red, bg = blend(syntax.red, p.bg, 0.12) },
	DiffText = { bg = blend(syntax.blue, p.bg, 0.25), bold = true },
	Search = { fg = theme.accent_foregrounds.command, bg = syntax.yellow },
	IncSearch = { fg = theme.accent_foregrounds.normal, bg = accent, bold = true },
	CurSearch = { link = "IncSearch" },
}) do
	vim.api.nvim_set_hl(0, name, spec)
end
