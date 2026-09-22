-- isolate GUI-only behavior so terminal Neovim remains unaffected.
if not vim.g.neovide then
	return
end

-- GUI launches on macOS do not reliably inherit the shell PATH.
local paths = require("dotfiles.core.path")
local path_sep = ":"
local path_entries = {}
for _, path in ipairs(vim.split(vim.env.PATH or "", path_sep, { plain = true, trimempty = true })) do
	path_entries[path] = true
end

local function prepend_path(path)
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= "directory" then
		return
	end

	if path_entries[path] then
		return
	end

	local current = vim.env.PATH or ""
	if current == "" then
		vim.env.PATH = path
	else
		vim.env.PATH = path .. path_sep .. current
	end
	path_entries[path] = true
end

for _, path in ipairs({
	vim.fn.expand("~/.local/bin"),
	vim.fn.expand("~/.local/share/mise/shims"),
	paths.homebrew("bin"),
}) do
	prepend_path(path)
end

-- Use the same Maple Mono family as Kitty while preserving each Neovide mode's tuned size.
-- Baking the sizes into guifont keeps <D-0> resetting to these values.
vim.o.guifont = vim.g.nvim_preview and "Maple_Mono_NF:h15.7" or "Maple_Mono_NF:h15"
-- Neovide animates any large viewport jump as a scroll, so a buffer or tab
-- switch slides the new file up into place while the old one is still on
-- screen. Snap instead: this also covers Aerial replacing its Loading buffer
-- asynchronously, which otherwise animates the outline and edgebar redraw.
vim.g.neovide_scroll_animation_length = 0.0
vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_position_animation_length = 0.0

-- GUI-only shortcuts. <D-...> reaches Neovim from nowhere else, so these are
-- defined here rather than in the global key layer.
local map = vim.keymap.set
local function zoom(factor)
	return function()
		local current = vim.g.neovide_scale_factor or 1
		vim.g.neovide_scale_factor = factor == 0 and 1 or math.min(math.max(current * factor, 0.5), 3)
	end
end
map({ "n", "i", "v" }, "<D-s>", function()
	vim.cmd.write()
end, { desc = "Save" })
map("v", "<D-c>", function()
	vim.cmd([[normal! "+y]])
end, { silent = true, desc = "Copy" })
map({ "n", "i", "v", "c", "t" }, "<D-v>", function()
	vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
end, { silent = true, desc = "Paste" })
local zoom_modes = { "n", "i", "v", "c", "t" }
for _, binding in ipairs({
	{ "<D-=>", 1.1, "Increase" },
	{ "<D-+>", 1.1, "Increase" },
	{ "<D-->", 1 / 1.1, "Decrease" },
	{ "<D-0>", 0, "Reset" },
}) do
	map(zoom_modes, binding[1], zoom(binding[2]), { silent = true, desc = binding[3] .. " font size" })
end
