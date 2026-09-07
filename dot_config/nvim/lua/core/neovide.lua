-- isolate GUI-only behavior so terminal Neovim remains unaffected.
if not vim.g.neovide then
	return
end

-- GUI launches on macOS do not reliably inherit the shell PATH.
local paths = require("core.path")
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

-- Sized to where two `<D-->` presses landed (20 / 1.1^2 = 16.5, 19 / 1.1^2 = 15.7),
-- baked into guifont so <D-0> resets here instead of back to the old h20.
vim.o.guifont = vim.g.nvim_preview and "JetBrainsMono_NF:h15.7" or "JetBrainsMono_NF:h15"
-- Neovide animates any large viewport jump as a scroll, so a buffer or tab
-- switch slides the new file up into place while the old one is still on
-- screen. Snap instead: this also covers Aerial replacing its Loading buffer
-- asynchronously, which otherwise animates the outline and edgebar redraw.
vim.g.neovide_scroll_animation_length = 0.0
vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_position_animation_length = 0.0

local function save()
	vim.cmd.write()
end

local function copy()
	vim.cmd([[normal! "+y]])
end

local function paste()
	vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
end

local function zoom(factor)
	return function()
		local current = vim.g.neovide_scale_factor or 1
		vim.g.neovide_scale_factor = factor == 0 and 1 or math.min(math.max(current * factor, 0.5), 3)
	end
end

vim.keymap.set({ "n", "i", "v" }, "<D-s>", save, { desc = "Save" })
vim.keymap.set("v", "<D-c>", copy, { silent = true, desc = "Copy" })
vim.keymap.set({ "n", "i", "v", "c", "t" }, "<D-v>", paste, { silent = true, desc = "Paste" })

local zoom_modes = { "n", "i", "v", "c", "t" }
for _, mapping in ipairs({
	{ "<D-=>", 1.1, "Increase" },
	{ "<D-+>", 1.1, "Increase" },
	{ "<D-->", 1 / 1.1, "Decrease" },
	{ "<D-0>", 0, "Reset" },
}) do
	vim.keymap.set(zoom_modes, mapping[1], zoom(mapping[2]), { silent = true, desc = mapping[3] .. " font size" })
end
