local M = {}

local function compact_width(columns)
	-- Keep file-only results near 90 columns without overflowing smaller screens.
	return math.min(0.8, 90 / columns)
end

function M.open(root)
	-- Seed the root before FFF initializes and share compact file search across entry points.
	require("fff.conf").get().base_path = root
	local preview_width = require("fff.conf").get().layout.width
	local function toggle_preview()
		local picker = require("fff.picker_ui.picker_ui")
		local config = picker.state.config
		if not config then
			return
		end
		config.preview.enabled = not config.preview.enabled
		-- Restore the normal two-pane width only while the preview is visible.
		config.layout.width = config.preview.enabled and preview_width or compact_width
		picker.relayout()
	end
	return require("fff").find_files({
		cwd = root,
		preview = { enabled = false },
		layout = { width = compact_width },
		mappings = {
			i = { ["<C-.>"] = toggle_preview },
			n = { ["<C-.>"] = toggle_preview },
		},
	})
end

return M
