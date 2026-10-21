-- VSCode-style `renderWhitespace: "selection"`: whitespace glyphs only inside
-- the active visual selection. Replaces the hand-rolled extmark module that
-- lived in core/selection_whitespace.lua.
return {
	"mcauley-penney/visual-whitespace.nvim",
	event = "ModeChanged *:[vV\22]",
	opts = {
		-- Spaces and tabs share U+22C5, which renders smaller than the middle
		-- dot so selections stay quiet; the tab arrow was too noisy.
		list_chars = { space = "⋅", tab = "⋅" },
		-- No end-of-line glyph, matching the previous behavior.
		fileformat_chars = { unix = "", mac = "", dos = "" },
		-- No `highlight` here: the colorscheme defines VisualNonText, and a value
		-- passed here would override it on every theme switch.
	},
}
