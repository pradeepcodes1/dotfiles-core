-- reuse paired result/preview floats across diagnostics, references, and quickfix lists.
local jump_close_keys = {
	["<cr>"] = "jump_close",
	["<c-s>"] = "jump_split_close",
	["<c-v>"] = "jump_vsplit_close",
	["<2-leftmouse>"] = "jump_close",
}

local navigation_keys = {
	j = "next",
	k = "prev",
	["<down>"] = "next",
	["<up>"] = "prev",
}

-- Same chord as Telescope's refine, and the same stacking behavior: narrow what
-- is already shown, with the applied queries listed in the header. An empty
-- query clears the stack. Implementation lives in core.trouble_float.
local filter_keys = {
	["<c-space>"] = {
		action = function(view)
			require("core.trouble_float").fuzzy_filter(view)
		end,
		desc = "Fuzzy filter",
	},
}

local paired_float_win = {
	type = "float",
	relative = "editor",
	border = "rounded",
	title_pos = "center",
	position = { 0.5, 0.05 },
	size = { width = 0.48, height = 0.5 },
}

local paired_float_preview = {
	type = "float",
	relative = "editor",
	border = "rounded",
	title = " Preview ",
	title_pos = "center",
	position = { 0.5, 0.91 },
	size = { width = 0.42, height = 0.5 },
	zindex = 200,
}

local function paired_float_mode(mode, title, opts)
	return vim.tbl_deep_extend("force", {
		mode = mode,
		focus = true,
		follow = false,
		auto_preview = true,
		restore = true,
		keys = vim.tbl_deep_extend(
			"force",
			vim.deepcopy(jump_close_keys),
			vim.deepcopy(navigation_keys),
			vim.deepcopy(filter_keys)
		),
		win = vim.tbl_deep_extend("force", vim.deepcopy(paired_float_win), {
			title = title,
		}),
		preview = vim.deepcopy(paired_float_preview),
	}, opts or {})
end

return {
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			focus = false,
			auto_close = false,
			auto_refresh = true,
			auto_preview = false,
			follow = false,
			multiline = false,
			warn_no_results = false,
			win = {
				type = "split",
				position = "bottom",
				size = 12,
			},
			modes = {
				qflist_float = paired_float_mode("qflist", " Quickfix "),
				references_qflist_float = paired_float_mode("qflist", " References ", {
					auto_jump = true,
				}),
				diagnostics_float = paired_float_mode("diagnostics", " Problems "),
				diagnostics_buffer_float = paired_float_mode("diagnostics", " Buffer Problems ", {
					filter = { buf = 0 },
				}),
			},
		},
	},
}
