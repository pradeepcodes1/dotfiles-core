-- render imported Gogh palettes without requiring a colorscheme plugin per theme.
local raw, theme = require("core.theme").get_palette()
raw = raw or {}
theme = theme or {}
local palette = require("core.palette")
local blend = palette.blend
local rgb = palette.rgb

local function pick(name, fallback)
	return palette.pick(raw, name, fallback)
end

local p = {
	bg = pick("bg", "ui_bg"),
	fg = pick("fg", "ui_fg"),
	black = pick("black", "bg"),
	red = pick("red", "bright_red"),
	green = pick("green", "bright_green"),
	yellow = pick("yellow", "bright_yellow"),
	blue = pick("blue", "bright_blue"),
	magenta = pick("magenta", "bright_magenta"),
	cyan = pick("cyan", "bright_cyan"),
	white = pick("white", "fg"),
	bright_black = pick("bright_black", "black"),
	bright_red = pick("bright_red", "red"),
	bright_green = pick("bright_green", "green"),
	bright_yellow = pick("bright_yellow", "yellow"),
	bright_blue = pick("bright_blue", "blue"),
	bright_magenta = pick("bright_magenta", "magenta"),
	bright_cyan = pick("bright_cyan", "cyan"),
	bright_white = pick("bright_white", "white"),
}

local function luminance(hex)
	local r, g, b = rgb(hex)
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

local mode = theme.background or theme.mode
if mode ~= "dark" and mode ~= "light" then
	mode = luminance(p.bg) > 0.55 and "light" or "dark"
end
vim.o.background = mode

local accent = raw.ui_accent or raw.ui_active or p.blue
local border = raw.ui_border or blend(p.fg, p.bg, 0.16)
local inactive = raw.ui_inactive or blend(p.fg, p.bg, 0.09)
local comment = raw.prompt_path or p.bright_black
local syntax = mode == "dark"
		and {
			red = p.bright_red,
			green = p.bright_green,
			yellow = p.bright_yellow,
			blue = p.bright_blue,
			magenta = p.bright_magenta,
			cyan = p.bright_cyan,
		}
	or {
		red = p.red,
		green = p.green,
		yellow = p.yellow,
		blue = p.blue,
		magenta = p.magenta,
		cyan = p.cyan,
	}

local surface = blend(p.fg, p.bg, 0.055)
local surface_high = blend(p.fg, p.bg, 0.11)
local selection = blend(accent, p.bg, mode == "dark" and 0.28 or 0.18)
local search = blend(syntax.yellow, p.bg, mode == "dark" and 0.42 or 0.24)
local diff_add = blend(syntax.green, p.bg, mode == "dark" and 0.18 or 0.11)
local diff_change = blend(syntax.blue, p.bg, mode == "dark" and 0.18 or 0.1)
local diff_delete = blend(syntax.red, p.bg, mode == "dark" and 0.18 or 0.1)
local diagnostic_error_bg = blend(syntax.red, p.bg, 0.12)
local diagnostic_warn_bg = blend(syntax.yellow, p.bg, 0.12)
local diagnostic_info_bg = blend(syntax.blue, p.bg, 0.12)
local diagnostic_hint_bg = blend(syntax.cyan, p.bg, 0.12)

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd("syntax reset")
end
vim.g.colors_name = "dotfiles-gogh"

local terminal_colors = {
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
}
for index, color in ipairs(terminal_colors) do
	vim.g["terminal_color_" .. (index - 1)] = color
end

local groups = {
	-- Editor UI
	FloatBorder = { fg = border, bg = surface },
	FloatTitle = { fg = accent, bg = surface, bold = true },
	Cursor = { fg = p.bg, bg = p.fg },
	lCursor = { link = "Cursor" },
	CursorIM = { link = "Cursor" },
	TermCursor = { link = "Cursor" },
	TermCursorNC = { fg = p.bg, bg = comment },
	CursorLine = { bg = surface },
	CursorColumn = { bg = surface },
	Directory = { fg = syntax.blue, bold = true },
	EndOfBuffer = { fg = p.bg, bg = p.bg },
	ErrorMsg = { fg = syntax.red, bold = true },
	WinSeparator = { fg = border },
	FoldColumn = { fg = comment, bg = p.bg },
	SignColumn = { fg = comment, bg = p.bg },
	IncSearch = { fg = p.bg, bg = syntax.yellow, bold = true },
	CurSearch = { link = "IncSearch" },
	Search = { fg = p.fg, bg = search },
	Substitute = { fg = p.bg, bg = syntax.red, bold = true },
	LineNrAbove = { link = "LineNr" },
	LineNrBelow = { link = "LineNr" },
	MatchParen = { fg = syntax.yellow, bg = surface_high, bold = true },
	ModeMsg = { fg = syntax.green, bold = true },
	MsgSeparator = { fg = border },
	PmenuSel = { fg = p.fg, bg = selection, bold = true },
	PmenuKind = { fg = syntax.magenta, bg = surface },
	PmenuKindSel = { fg = syntax.magenta, bg = selection, bold = true },
	PmenuExtraSel = { fg = p.fg, bg = selection },
	PmenuThumb = { bg = comment },
	QuickFixLine = { bg = selection, bold = true },
	SpellBad = { undercurl = true, sp = syntax.red },
	SpellCap = { undercurl = true, sp = syntax.blue },
	SpellLocal = { undercurl = true, sp = syntax.cyan },
	SpellRare = { undercurl = true, sp = syntax.magenta },
	StatusLine = { fg = p.fg, bg = surface_high },
	TabLineFill = { bg = surface },
	TabLineSel = { fg = accent, bg = surface_high, bold = true },
	WildMenu = { fg = p.bg, bg = accent, bold = true },
	WinBarNC = { fg = comment, bg = p.bg },

	-- Vim syntax
	Comment = { fg = comment, italic = true },
	Boolean = { fg = syntax.magenta, bold = true },
	Float = { link = "Number" },
	Keyword = { fg = syntax.magenta, italic = true },
	SpecialComment = { fg = syntax.cyan, italic = true },
	Underlined = { fg = syntax.blue, underline = true },
	Todo = { fg = p.bg, bg = syntax.yellow, bold = true },

	-- Treesitter
	["@boolean"] = { link = "Boolean" },
	["@character"] = { link = "Character" },
	["@character.special"] = { link = "SpecialChar" },
	["@comment"] = { link = "Comment" },
	["@comment.documentation"] = { link = "SpecialComment" },
	["@comment.error"] = { fg = syntax.red, bold = true },
	["@comment.hint"] = { fg = syntax.cyan, bold = true },
	["@comment.info"] = { fg = syntax.blue, bold = true },
	["@comment.note"] = { fg = syntax.blue, bold = true },
	["@comment.todo"] = { link = "Todo" },
	["@constant"] = { link = "Constant" },
	["@constant.builtin"] = { fg = syntax.magenta, bold = true },
	["@constant.macro"] = { link = "Macro" },
	["@diff.delta"] = { link = "DiffChange" },
	["@diff.minus"] = { link = "DiffDelete" },
	["@diff.plus"] = { link = "DiffAdd" },
	["@function.macro"] = { link = "Macro" },
	["@keyword"] = { link = "Keyword" },
	["@keyword.conditional"] = { link = "Conditional" },
	["@keyword.coroutine"] = { fg = syntax.magenta, italic = true },
	["@keyword.debug"] = { link = "Debug" },
	["@keyword.exception"] = { link = "Exception" },
	["@keyword.function"] = { fg = syntax.magenta, italic = true },
	["@keyword.import"] = { link = "Include" },
	["@keyword.modifier"] = { link = "StorageClass" },
	["@keyword.operator"] = { link = "Operator" },
	["@keyword.repeat"] = { link = "Repeat" },
	["@keyword.return"] = { fg = syntax.magenta, italic = true },
	["@label"] = { link = "Label" },
	["@markup.emphasis"] = { italic = true },
	["@markup.italic"] = { italic = true },
	["@markup.link"] = { fg = syntax.blue, underline = true },
	["@markup.link.url"] = { fg = syntax.blue, underline = true },
	["@markup.quote"] = { fg = comment, italic = true },
	["@markup.strikethrough"] = { strikethrough = true },
	["@markup.strong"] = { bold = true },
	["@markup.underline"] = { underline = true },
	["@module.builtin"] = { fg = syntax.yellow, italic = true },
	["@number"] = { link = "Number" },
	["@number.float"] = { link = "Float" },
	["@operator"] = { link = "Operator" },
	["@string"] = { link = "String" },
	["@string.documentation"] = { fg = syntax.green, italic = true },
	["@string.special.path"] = { fg = syntax.green, underline = true },
	["@string.special.url"] = { fg = syntax.blue, underline = true },
	["@type"] = { link = "Type" },
	["@type.builtin"] = { fg = syntax.yellow, italic = true },
	["@type.definition"] = { link = "Typedef" },
	["@variable.builtin"] = { fg = syntax.magenta, italic = true },
	["@variable.parameter"] = { fg = p.fg, italic = true },

	-- Diagnostics and LSP semantic tokens
	DiagnosticVirtualTextError = { fg = syntax.red, bg = diagnostic_error_bg },
	DiagnosticVirtualTextWarn = { fg = syntax.yellow, bg = diagnostic_warn_bg },
	DiagnosticVirtualTextInfo = { fg = syntax.blue, bg = diagnostic_info_bg },
	DiagnosticVirtualTextHint = { fg = syntax.cyan, bg = diagnostic_hint_bg },
	DiagnosticVirtualTextOk = { fg = syntax.green, bg = diff_add },
	DiagnosticUnderlineError = { undercurl = true, sp = syntax.red },
	DiagnosticUnderlineWarn = { undercurl = true, sp = syntax.yellow },
	DiagnosticUnderlineInfo = { undercurl = true, sp = syntax.blue },
	DiagnosticUnderlineHint = { undercurl = true, sp = syntax.cyan },
	DiagnosticUnderlineOk = { undercurl = true, sp = syntax.green },
	DiagnosticFloatingError = { fg = syntax.red, bg = surface },
	DiagnosticFloatingWarn = { fg = syntax.yellow, bg = surface },
	DiagnosticFloatingInfo = { fg = syntax.blue, bg = surface },
	DiagnosticFloatingHint = { fg = syntax.cyan, bg = surface },
	DiagnosticFloatingOk = { fg = syntax.green, bg = surface },
	LspReferenceWrite = { bg = selection, bold = true },
	LspSignatureActiveParameter = { fg = syntax.yellow, bg = surface_high, bold = true },
	["@lsp.type.class"] = { link = "Type" },
	["@lsp.type.comment"] = { link = "Comment" },
	["@lsp.type.decorator"] = { link = "@attribute" },
	["@lsp.type.enum"] = { link = "Type" },
	["@lsp.type.enumMember"] = { link = "Constant" },
	["@lsp.type.interface"] = { link = "Type" },
	["@lsp.type.keyword"] = { link = "Keyword" },
	["@lsp.type.macro"] = { link = "Macro" },
	["@lsp.type.modifier"] = { link = "StorageClass" },
	["@lsp.type.namespace"] = { link = "@module" },
	["@lsp.type.number"] = { link = "Number" },
	["@lsp.type.operator"] = { link = "Operator" },
	["@lsp.type.parameter"] = { link = "@variable.parameter" },
	["@lsp.type.property"] = { link = "@property" },
	["@lsp.type.regexp"] = { link = "@string.regexp" },
	["@lsp.type.string"] = { link = "String" },
	["@lsp.type.struct"] = { link = "Structure" },
	["@lsp.type.type"] = { link = "Type" },
	["@lsp.type.typeParameter"] = { link = "Typedef" },
	["@lsp.type.variable"] = { link = "@variable" },
	["@lsp.typemod.variable.defaultLibrary"] = { link = "@variable.builtin" },
	["@lsp.typemod.variable.readonly"] = { link = "Constant" },

	-- Diff, version control, and common plugins
	DiffAdd = { bg = diff_add },
	DiffChange = { bg = diff_change },
	DiffDelete = { fg = syntax.red, bg = diff_delete },
	DiffText = { bg = blend(syntax.blue, p.bg, 0.3), bold = true },
	GitSignsCurrentLineBlame = { fg = comment, italic = true },
	GitSignsAddInline = { bg = blend(syntax.green, p.bg, 0.25) },
	GitSignsChangeInline = { bg = blend(syntax.blue, p.bg, 0.25) },
	GitSignsDeleteInline = { bg = blend(syntax.red, p.bg, 0.25) },

	TelescopeBorder = { fg = border, bg = surface },
	TelescopePromptNormal = { fg = p.fg, bg = surface_high },
	TelescopePromptBorder = { fg = accent, bg = surface_high },
	TelescopeSelection = { bg = selection, bold = true },
	TelescopeSelectionCaret = { fg = accent, bg = selection },

	NeoTreeTabActive = { fg = accent, bg = surface_high, bold = true },
	NvimTreeNormal = { link = "NeoTreeNormal" },
	NvimTreeFolderIcon = { link = "NeoTreeDirectoryIcon" },
	NvimTreeFolderName = { link = "NeoTreeDirectoryName" },
	NvimTreeRootFolder = { link = "NeoTreeRootName" },

	BufferCurrent = { fg = p.fg, bg = surface_high, bold = true },
	BufferCurrentIndex = { fg = accent, bg = surface_high },
	BufferCurrentMod = { fg = syntax.yellow, bg = surface_high },
	BufferCurrentSign = { fg = accent, bg = surface_high },
	BufferInactiveMod = { fg = syntax.yellow, bg = surface },
	BufferInactiveSign = { fg = inactive, bg = surface },
	BufferVisibleIndex = { fg = accent, bg = surface },
	BufferTabpageFill = { bg = p.bg },
	BufferTabpages = { fg = p.bg, bg = accent, bold = true },
	BufferLineFill = { bg = p.bg },
	BufferLineBufferSelected = { fg = p.fg, bg = surface_high, bold = true },
	BufferLineIndicatorSelected = { fg = accent, bg = surface_high },
	BufferLineModifiedSelected = { fg = syntax.yellow, bg = surface_high },

	CmpItemAbbrDeprecated = { fg = comment, strikethrough = true },
	BlinkCmpLabelDeprecated = { fg = comment, strikethrough = true },

	WhichKeyFloat = { bg = surface },
	LazyButtonActive = { fg = p.bg, bg = accent, bold = true },
	LazyH1 = { fg = p.bg, bg = accent, bold = true },
	MasonHeader = { fg = p.bg, bg = accent, bold = true },
	MasonHighlightBlock = { fg = p.bg, bg = accent },

	TroubleCount = { fg = syntax.magenta, bg = surface_high },
	DapStopped = { fg = syntax.green, bg = diff_add },

	NoiceCmdlinePopupBorder = { fg = accent, bg = surface },
	NoiceConfirmBorder = { fg = syntax.yellow, bg = surface },

	SnacksDashboardFooter = { fg = comment, italic = true },
	TodoFgTODO = { fg = syntax.blue, bold = true },
	TodoFgFIX = { fg = syntax.red, bold = true },
	TodoFgNOTE = { fg = syntax.cyan, bold = true },
	TodoBgTODO = { fg = p.bg, bg = syntax.blue, bold = true },
	TodoBgFIX = { fg = p.bg, bg = syntax.red, bold = true },
	TodoBgWARN = { fg = p.bg, bg = syntax.yellow, bold = true },
	TodoBgNOTE = { fg = p.bg, bg = syntax.cyan, bold = true },
}

local function define(spec, names)
	for name in names:gmatch("%S+") do
		groups[name] = spec
	end
end

-- Reuse exact definitions for groups with identical styling.
define(
	{ fg = p.fg, bg = p.bg },
	[[
Normal NormalNC WinBar NeoTreeNormal NeoTreeNormalNC TroubleNormal TroubleNormalNC
]]
)
define(
	{ fg = p.fg, bg = surface },
	[[
NormalFloat Pmenu TelescopeNormal BufferVisible BufferOffset BufferLineBufferVisible BlinkCmpMenu LazyButton
NoiceCmdlinePopup NoiceConfirm
]]
)
define(
	{ bg = surface_high },
	[[
ColorColumn PmenuSbar LspReferenceText LspReferenceRead IlluminatedWordText IlluminatedWordRead
]]
)
define(
	{ fg = comment },
	[[
Conceal LineNr Delimiter Ignore @punctuation.bracket @punctuation.delimiter @tag.delimiter CmpItemMenu
WhichKeySeparator WhichKeyValue MasonMuted TroubleCode NotifyDEBUGBorder NotifyDEBUGIcon NotifyDEBUGTitle
]]
)
define(
	{ fg = comment, bg = surface },
	[[
Folded PmenuExtra StatusLineNC TabLine NeoTreeTabInactive BufferInactive BufferInactiveIndex
BufferLineBuffer MasonMutedBlock
]]
)
define(
	{ fg = accent, bold = true },
	[[
CursorLineNr Title @markup.heading TelescopeTitle NeoTreeRootName NeoTreeFileNameOpened CmpItemAbbrMatch
BlinkCmpLabelMatch LazyH2
]]
)
define(
	{ fg = accent },
	[[
CursorLineFold CursorLineSign TelescopePromptPrefix CmpItemAbbrMatchFuzzy WhichKey MasonHighlight
DapUILineNumber NoiceCmdlineIcon SnacksDashboardHeader IndentBlanklineContextChar IblScope
]]
)
define(
	{ fg = p.fg },
	[[
MsgArea Identifier @variable CmpItemAbbr BlinkCmpLabel WhichKeyDesc TroubleText DapUIVariable
SnacksDashboardDesc
]]
)
define(
	{ fg = syntax.cyan },
	[[
MoreMsg Operator Special SpecialChar @function.builtin @markup.link.label @markup.math @property
@punctuation.special @string.escape @string.regexp @string.special @variable.member DiagnosticHint
DiagnosticSignHint NeoTreeGitUntracked WhichKeyGroup LazySpecial AerialVariableIcon DapUIScope
SnacksDashboardIcon
]]
)
define(
	{ fg = inactive },
	[[
NonText SpecialKey Whitespace NeoTreeIndentMarker AerialGuide IndentBlanklineChar IblIndent
]]
)
define(
	{ fg = syntax.green },
	[[
Question String Character @markup.raw @markup.raw.block DiagnosticOk DiagnosticSignOk diffAdded diffNewFile
GitSignsAdd NeoTreeGitAdded DapUIValue DapUIThread
]]
)
define(
	{ bg = selection },
	[[
Visual VisualNOS BlinkCmpMenuSelection AerialLine SnacksPickerListCursorLine IlluminatedWordWrite
]]
)
define(
	{ fg = syntax.yellow, bold = true },
	[[
WarningMsg @comment.warning TelescopeMatching SnacksDashboardKey SnacksPickerMatch TodoFgWARN
]]
)
define(
	{ fg = syntax.magenta },
	[[
Constant Number Statement Conditional Repeat Include Define @markup.environment @markup.list
@string.special.symbol CmpItemKind BlinkCmpKind DapUISource NotifyTRACEBorder NotifyTRACEIcon
NotifyTRACETitle SnacksDashboardSpecial
]]
)
define(
	{ fg = syntax.blue },
	[[
Function Tag @constructor @tag DiagnosticInfo DiagnosticSignInfo diffChanged GitSignsChange
NeoTreeDirectoryIcon NeoTreeDirectoryName AerialFunctionIcon AerialMethodIcon NotifyINFOBorder
NotifyINFOIcon NotifyINFOTitle
]]
)
define(
	{ fg = syntax.yellow },
	[[
Label PreProc Macro PreCondit Type StorageClass Structure Typedef @attribute @module @tag.attribute
DiagnosticWarn DiagnosticSignWarn @lsp.type.event NeoTreeGitModified AerialClassIcon DapBreakpointCondition
DapUIType DapUIStoppedThread NotifyWARNBorder NotifyWARNIcon NotifyWARNTitle
]]
)
define(
	{ fg = syntax.red },
	[[
Exception Debug Error DiagnosticError DiagnosticSignError diffRemoved diffOldFile GitSignsDelete
NeoTreeGitConflict NeoTreeGitDeleted DapBreakpoint NotifyERRORBorder NotifyERRORIcon NotifyERRORTitle
]]
)
define(
	{ link = "Function" },
	[[
@function @function.call @function.method @function.method.call @lsp.type.function @lsp.type.method
]]
)

for name, spec in pairs(groups) do
	vim.api.nvim_set_hl(0, name, spec)
end
