-- VSCode-style `renderWhitespace: "selection"`: show spaces/tabs as glyphs only
-- inside the active visual selection. 'list' is window-wide, so overlay extmarks
-- are used instead and cleared as soon as visual mode ends.
local ns = vim.api.nvim_create_namespace("selection_whitespace")
local group = vim.api.nvim_create_augroup("selection_whitespace", { clear = true })
-- Tabs use the same dot as spaces; the arrow was too noisy.
local glyphs = { [" "] = "·", ["\t"] = "·" }
local marked_buf
-- Theme `Whitespace` is too dark to read on the Visual background; default
-- to the comment grey while still letting a colorscheme override it.
vim.api.nvim_set_hl(0, "SelectionWhitespace", { link = "Comment", default = true })

local function clear()
	if marked_buf and vim.api.nvim_buf_is_valid(marked_buf) then
		vim.api.nvim_buf_clear_namespace(marked_buf, ns, 0, -1)
	end
	marked_buf = nil
end

local function render()
	clear()
	local mode = vim.fn.mode()
	if not (mode == "v" or mode == "V" or mode == "\22") then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	-- Only visible rows matter; selecting a whole large file stays cheap.
	local top, bottom = vim.fn.line("w0"), vim.fn.line("w$")
	local ok, regions = pcall(vim.fn.getregionpos, vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
	if not ok then
		return
	end
	marked_buf = buf
	for _, region in ipairs(regions) do
		local s, e = region[1], region[2]
		local lnum = s[2]
		if lnum >= top and lnum <= bottom then
			local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
			-- getregionpos reports a huge end col for linewise / `$` selections.
			local last = math.min(e[3], #line)
			for col = s[3], last do
				local glyph = glyphs[line:sub(col, col)]
				if glyph then
					vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col - 1, {
						virt_text = { { glyph, "SelectionWhitespace" } },
						virt_text_pos = "overlay",
						-- Keep the Visual background under the glyph.
						hl_mode = "combine",
					})
				end
			end
		end
	end
end

vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved", "WinScrolled" }, {
	group = group,
	desc = "Show whitespace glyphs inside the visual selection",
	callback = render,
})
