-- keep JDT virtual buffers readable by replacing opaque URIs with Java class names.
return {
	{
		"romgrk/barbar.nvim",
		enabled = not vim.g.nvim_preview,
		dependencies = {
			"lewis6991/gitsigns.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		init = function()
			vim.g.barbar_auto_setup = false
		end,
		opts = {
			icons = {
				buffer_index = true,
				modified = { button = "\xef\x91\x84" },
				pinned = { button = "\xef\xa4\x82", filename = true },
				separator_at_end = false,
			},
		},
		config = function(_, opts)
			require("barbar").setup(opts)

			local jdt = require("core.jdt")
			local state = require("barbar.state")
			local orig_update_names = state.update_names

			function state.update_names()
				orig_update_names()
				for _, bufnr in ipairs(state.buffers) do
					-- state.buffers can still hold a just-deleted id: barbar re-renders
					-- from inside its own close animation, so this runs while the list is
					-- mid-update, which restoring a session makes routine. Upstream reads
					-- names through buffer.get_name, which guards the same way.
					if vim.api.nvim_buf_is_valid(bufnr) then
						local bufname = vim.api.nvim_buf_get_name(bufnr)
						if jdt.is_jdt(bufname) then
							local clean = jdt.classname(bufname)
							if clean then
								state.get_buffer_data(bufnr).name = clean
							end
						end
					end
				end
			end
		end,
		version = "^1.0.0",
	},
}
