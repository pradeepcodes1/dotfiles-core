-- keep JDT virtual buffers readable by replacing opaque URIs with Java class
-- names, and mark the buffers that are not project source.
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
			local library_paths = require("core.library_paths")
			local path_util = require("core.path")
			local project = require("core.project")
			local state = require("barbar.state")
			local orig_update_names = state.update_names

			-- middle dot (U+00B7)
			local OUTSIDE_ICON = "·"

			-- The root every buffer is judged against, resolved once per pass
			-- rather than per buffer. Only project mode has a root worth judging
			-- against: outside it project.current_root() answers from the buffer
			-- it is asked in, so each tab would be measured against whichever
			-- buffer happens to be current and the marks would move as you cycle.
			local function project_root()
				if not project.is_open() then
					return nil
				end

				return project.session_root() or path_util.normalize(vim.g.project_root)
			end

			-- Dependency and toolchain files sit *under* the root, so the
			-- containment test alone would call node_modules project source.
			local function is_outside(bufname, root)
				if jdt.is_jdt(bufname) then
					return true
				end

				-- terminals and the other non-file buffers are named term:// and
				-- friends; they have no place to be outside of.
				if bufname == "" or bufname:match("^%w+://") then
					return false
				end

				if library_paths.contains(bufname) then
					return true
				end

				return root ~= nil and not path_util.under(path_util.normalize(bufname), root)
			end

			function state.update_names()
				orig_update_names()
				local root = project_root()
				for _, bufnr in ipairs(state.buffers) do
					-- state.buffers can still hold a just-deleted id: barbar re-renders
					-- from inside its own close animation, so this runs while the list is
					-- mid-update, which restoring a session makes routine. Upstream reads
					-- names through buffer.get_name, which guards the same way.
					if vim.api.nvim_buf_is_valid(bufnr) then
						local bufname = vim.api.nvim_buf_get_name(bufnr)
						local data = state.get_buffer_data(bufnr)
						if jdt.is_jdt(bufname) then
							local clean = jdt.classname(bufname)
							if clean then
								data.name = clean
							end
						end

						-- orig_update_names() rewrites every name from scratch each
						-- pass, so the marker cannot accumulate across renders.
						if is_outside(bufname, root) then
							data.name = (data.name or "") .. " " .. OUTSIDE_ICON
						end
					end
				end
			end
		end,
		version = "^1.0.0",
	},
}
