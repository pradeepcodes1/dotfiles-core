-- expose useful editor and Java context while following the active palette.
return {
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			local jdt = require("core.jdt")
			local statusline_disabled = {
				"dap-repl",
				"dapui_console",
				"dapui_scopes",
				"dapui_breakpoints",
				"dapui_stacks",
				"dapui_watches",
				"aerial",
				"neo-tree",
				"neotest-summary",
				"neotest-output-panel",
			}
			local winbar_disabled = vim.list_extend(vim.deepcopy(statusline_disabled), {
				"qf",
				"lazy",
				"mason",
				"snacks_dashboard",
			})

			local function smart_path()
				local path = vim.fn.expand("%:p")
				if path == "" then
					return ""
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

			-- Lualine theme compiled from the active Gogh palette.
			local lualine_theme = os.getenv("_DOTFILES_NVIM_LUALINE") or "dotfiles-gogh"

			require("lualine").setup({
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { "" },
					lualine_x = { smart_path },
					lualine_y = { "progress" },
					lualine_z = { "location" },
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
		end,
	},
}
