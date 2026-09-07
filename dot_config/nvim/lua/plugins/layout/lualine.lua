-- expose useful editor and Java context while following the active palette.
return {
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			local cli = require("core.cli")
			local jdt = require("lsp.java.classfile")
			local project_state = require("project.state")
			local project_paths = require("project.paths")
			local path_util = require("core.path")
			local theme_state = require("theme")
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
					age = cli.git(root, "show", "-s", "--format=%cr", rev.commit) or ""
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

				if vim.bo.buftype == "" and project_state.is_open() then
					local root = project_paths.current_root()
					local normalized = path_util.normalize(path)
					if path_util.under(normalized, root) then
						return vim.fs.relpath(root, normalized)
					end
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

			-- Each window owns its filename; duplicate basenames retain their path context.
			local function window_label()
				local path = vim.api.nvim_buf_get_name(0)
				local name = vim.fs.basename(path)
				local label = name ~= "" and name or "[No Name]"
				if vim.bo.buftype ~= "" or jdt.is_jdt(path) then
					label = smart_path()
				else
					for _, buf in ipairs(vim.api.nvim_list_bufs()) do
						local other = vim.api.nvim_buf_get_name(buf)
						if vim.bo[buf].buflisted and other ~= path and vim.fs.basename(other) == name then
							label = smart_path()
							break
						end
					end
				end
				return label .. (vim.bo.modified and " ●" or "") .. (vim.bo.readonly and " " or "")
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
				local resolved = theme_state.current()
				local lualine_theme = resolved.lualine
				if lualine_theme == "dotfiles-gogh" then
					lualine_theme = require("theme.lualine").build(resolved)
				end

				-- A single bottom bar owns tab navigation even when a sidebar has focus.
				vim.o.showtabline = 0
				vim.o.tabline = ""
				require("lualine").setup({
					sections = {
						lualine_a = { "mode" },
						lualine_b = vim.g.nvim_preview and {} or {
							{
								"tabs",
								mode = 2,
								path = 0,
								max_length = function()
									return math.floor(vim.o.columns * 0.45)
								end,
								tabs_color = {
									active = { fg = resolved.accents.normal, bg = resolved.selection },
									inactive = { fg = resolved.muted, bg = resolved.section_bg },
								},
								symbols = { modified = " ●" },
							},
						},
						lualine_c = { "branch", "diff" },
						lualine_x = { "diagnostics" },
						lualine_y = { { "filetype", colored = false } },
						lualine_z = { location },
					},
					-- Winbars identify their own buffer rather than repeating workspace status.
					winbar = {
						lualine_c = {
							{ window_label, color = { fg = resolved.palette.fg, bg = resolved.palette.bg } },
							vim.deepcopy(breadcrumb_component),
						},
					},
					inactive_winbar = {
						lualine_c = {
							{ window_label, color = { fg = resolved.muted, bg = resolved.palette.bg } },
							vim.deepcopy(breadcrumb_component),
						},
					},
					tabline = {},
					options = {
						theme = lualine_theme,
						globalstatus = true,
						section_separators = "",
						component_separators = "",
						disabled_filetypes = { statusline = {}, winbar = winbar_disabled },
					},
				})
				-- Disabling lualine's tabline restores its saved option, so hide it after setup.
				vim.o.showtabline = 0
			end

			-- Older sessions may restore the former top tabline and per-window statuslines.
			vim.api.nvim_create_autocmd("SessionLoadPost", {
				group = vim.api.nvim_create_augroup("DotfilesStatusLayout", { clear = true }),
				callback = function()
					vim.o.showtabline = 0
					vim.o.laststatus = 3
				end,
			})

			apply()

			-- A live reload publishes a new snapshot before notifying consumers.
			vim.api.nvim_create_autocmd("User", {
				pattern = "DotfilesThemeChanged",
				callback = apply,
			})
		end,
	},
}
