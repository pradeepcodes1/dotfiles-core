-- label relative lines with left-hand digits only (1..5, 11..55, ...) so a
-- vertical jump keeps the counting hand on the left and j/k on the right.
-- The labels are remapped back to real counts, so 11j still moves 6 lines.
return {
	"mluders/comfy-line-numbers.nvim",

	-- Rendering happens through 'statuscolumn' and the autocmds setup()
	-- installs, so it only has to be loaded once the UI exists.
	event = "VeryLazy",

	-- Defaults already blank the column for terminal and nofile buffers, which
	-- covers betterterm, the Snacks explorer, dashboard and Aerial here.
	opts = {},
}
