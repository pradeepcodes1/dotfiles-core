-- expose useful editor and Java context while following the active palette.
return {
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			local jdt = require("core.jdt")
			local diffview_commit_ages = {}
			local statusline_disabled = {
				"dap-repl",
				"dapui_console",
				"dapui_scopes",
				"dapui_breakpoints",
				"dapui_stacks",
				"dapui_watches",
				"aerial",
				"snacks_picker_list",
				"neotest-summary",
				"neotest-output-panel",
			}
			local winbar_disabled = vim.list_extend(vim.deepcopy(statusline_disabled), {
				"qf",
				"lazy",
				"mason",
				"snacks_dashboard",
			})

			local function diffview_revision()
				local ok_lib, lib = pcall(require, "diffview.lib")
				local ok_rev, rev_module = pcall(require, "diffview.vcs.rev")
				if not ok_lib or not ok_rev then
					return nil
				end

				local view = lib.get_current_view()
				if not view or not view.cur_layout then
					return nil
				end

				local file
				local winid = vim.api.nvim_get_current_win()
				for _, window in ipairs(view.cur_layout.windows or {}) do
					if window.id == winid then
						file = window.file
						break
					end
				end

				local rev = file and file.rev
				if not rev then
					return nil
				end

				local RevType = rev_module.RevType
				if rev.type == RevType.LOCAL then
					return "WORKING TREE"
				elseif rev.type == RevType.STAGE then
					return ({ [0] = "INDEX", [1] = "BASE", [2] = "OURS", [3] = "THEIRS" })[rev.stage]
				elseif rev.type ~= RevType.COMMIT or not rev.commit then
					return nil
				end

				local root = view.adapter and view.adapter.ctx and view.adapter.ctx.toplevel
				local cache_key = (root or "") .. "\0" .. rev.commit
				local age = diffview_commit_ages[cache_key]
				if age == nil then
					local output = root
							and vim.fn.systemlist({
								"git",
								"-C",
								root,
								"show",
								"-s",
								"--format=%cr",
								rev.commit,
							})
						or {}
					age = vim.v.shell_error == 0 and vim.trim(output[1] or "") or ""
					diffview_commit_ages[cache_key] = age
				end

				local label = rev.track_head and "HEAD" or rev:abbrev(7)
				return age ~= "" and (label .. " · " .. age) or label
			end

			local function smart_path()
				local revision = diffview_revision()
				if revision then
					return revision
				end

				local path = vim.fn.expand("%:p")
				if path == "" then
					return ""
				end

				-- Diffview's winbar identifies the revision; avoid repeating its
				-- internal diffview:// buffer URI in the statusline.
				if vim.startswith(path, "diffview://") then
					return vim.fn.expand("%:t")
				end

				if jdt.is_jdt(path) then
					local fqcn = jdt.fqcn(path)
					return jdt.JAVA_ICON .. " " .. (fqcn or path) .. " (decompiled)"
				end

				if vim.fn.winwidth(0) < 80 then
					return vim.fn.expand("%:t")
				end

				local home = vim.fn.expand("$HOME")
				if path == home or vim.startswith(path, home .. "/") then
					return "~" .. path:sub(#home + 1)
				end

				return path
			end

			-- The builtin `location` component stops at the cursor; append the
			-- buffer's line count so the position reads as "line X of Y" rather
			-- than a number with nothing to measure against.
			local function location()
				return string.format("%d:%d/%d", vim.fn.line("."), vim.fn.col("."), vim.api.nvim_buf_line_count(0))
			end

			local function breadcrumb_available()
				local bufnr = vim.api.nvim_get_current_buf()
				return vim.bo[bufnr].buftype == "" and vim.bo[bufnr].filetype ~= ""
			end

			local breadcrumb_component = {
				"aerial",
				cond = breadcrumb_available,
				exact = false,
				sep = " > ",
			}

			local function apply()
				-- Lualine theme compiled from the active Gogh palette.
				local lualine_theme = os.getenv("_DOTFILES_NVIM_LUALINE") or "dotfiles-gogh"

				require("lualine").setup({
					sections = {
						lualine_a = { "mode" },
						lualine_b = { "branch", "diff", "diagnostics" },
						lualine_c = { "" },
						lualine_x = { smart_path },
						lualine_y = { "progress" },
						lualine_z = { location },
					},
					winbar = {
						lualine_c = {
							vim.deepcopy(breadcrumb_component),
						},
					},
					inactive_winbar = {
						lualine_c = {
							vim.deepcopy(breadcrumb_component),
						},
					},
					options = {
						theme = lualine_theme,
						disabled_filetypes = {
							statusline = statusline_disabled,
							winbar = winbar_disabled,
						},
					},
				})
			end

			apply()

			-- A live theme reload (`:DotfilesThemeReload`, from a Noctalia palette
			-- change) re-sources core/theme.lua's env vars but Lua caches the
			-- required theme module, so drop that cache entry before reapplying.
			vim.api.nvim_create_autocmd("User", {
				pattern = "DotfilesThemeChanged",
				callback = function()
					package.loaded["lualine.themes.dotfiles-gogh"] = nil
					apply()
				end,
			})
		end,
	},
}
