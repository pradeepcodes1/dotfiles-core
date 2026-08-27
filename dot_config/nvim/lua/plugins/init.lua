-- keep foundational editor plugins and Telescope result handoff in one load path.
local function telescope_send_to_quickfix(prompt_bufnr)
	local actions = require("telescope.actions")
	actions.smart_send_to_qflist(prompt_bufnr)
	actions.close(prompt_bufnr)
	vim.schedule(function()
		require("core.quickfix").open_float()
	end)
end

return {
	----------------------------------------
	-- Core UX
	----------------------------------------
	{ "nvim-lua/plenary.nvim" }, -- lua helpers
	{ "nvim-tree/nvim-web-devicons" },
	{ "folke/which-key.nvim", event = "VeryLazy", config = true },
	{
		"nvim-telescope/telescope.nvim",
		tag = "v0.2.1",
		dependencies = { "plenary.nvim" },
		opts = {
			defaults = {
				preview = {
					-- telescope's buffer previewer still calls the old
					-- nvim-treesitter `ft_to_lang` API, removed on the
					-- `main` branch; fall back to regex/syntax highlighting.
					treesitter = false,
				},
				mappings = {
					i = { ["<C-q>"] = telescope_send_to_quickfix },
					n = { ["<C-q>"] = telescope_send_to_quickfix },
				},
				file_ignore_patterns = {
					-- Version control
					"%.git/",
					"%.svn/",
					"%.hg/",

					-- Dependencies
					"node_modules/",
					"vendor/",
					"%.bundle/",
					"bower_components/",

					-- Build outputs
					"build/",
					"dist/",
					"out/",
					"target/",
					"%.min%.js$",
					"%.min%.css$",

					-- Caches
					"%.cache/",
					"%.next/",
					"%.nuxt/",
					"%.turbo/",
					"%.vite/",
					"%.parcel%-cache/",

					-- Test/coverage
					"coverage/",
					"%.nyc_output/",
					"%.pytest_cache/",
					"__pycache__/",

					-- Lock files
					"package%-lock%.json$",
					"yarn%.lock$",
					"pnpm%-lock%.yaml$",
					"Cargo%.lock$",
					"poetry%.lock$",

					-- OS/IDE
					"%.DS_Store$",
					"Thumbs%.db$",
					"%.idea/",
					"%.vscode/",

					-- Logs
					"%.log",
					"npm%-debug%.log$",
					"yarn%-error%.log$",
				},
			},
			pickers = {
				find_files = {
					find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" },
				},
			},
		},
	},
	----------------------------------------
	-- Git & coding aids
	----------------------------------------
	{ "windwp/nvim-autopairs", event = "InsertEnter", config = true },
	{ "numToStr/Comment.nvim", event = "VeryLazy", config = true },

	----------------------------------------
	-- LSP, diagnostics, formatting
	----------------------------------------
	{
		"nvim-java/nvim-java",
		ft = "java", -- lazy load only for Java files
		config = function()
			require("java").setup({
				java_test = {
					enable = false,
				},
				java_debug_adapter = {
					enable = false,
				},
				spring_boot_tools = {
					enable = false,
				},
			})
			vim.lsp.config("jdtls", {
				handlers = {
					["$/progress"] = function() end,
					["language/status"] = function() end,
				},
			})
			vim.lsp.enable("jdtls")
		end,
	},

	{ "neovim/nvim-lspconfig" },
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
		},
	},

	----------------------------------------
	-- Python specifics
	----------------------------------------
	{ "linux-cultist/venv-selector.nvim", cmd = "VenvSelect", opts = { search_venv_managers = false } },

	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		---@type snacks.Config
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
			bigfile = { enabled = true },
			dashboard = {
				enabled = not vim.g.nvim_preview,
				preset = {
					keys = {
						{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
						{
							icon = " ",
							key = "r",
							desc = "Recent Files",
							action = ":Telescope oldfiles",
						},
						{ icon = "", key = "p", desc = "Projects", action = "<leader>p" },
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
				},
				sections = {
					{ section = "keys", gap = 1, padding = 1 },
				},
			},
			indent = {
				enabled = true,

				animate = {
					style = "up",
					duration = {
						total = 15,
					},
				},
			},
			input = { enabled = true },
			quickfile = { enabled = true },
			scope = { enabled = true },
			statuscolumn = { enabled = true },
			words = { enabled = true },
		},
		keys = {
			{
				"<leader>.",
				function()
					Snacks.scratch()
				end,
				desc = "Toggle Scratch Buffer",
			},
			{
				"<leader>S",
				function()
					Snacks.scratch.select()
				end,
				desc = "Select Scratch Buffer",
			},
		},
	},
	{
		"sindrets/diffview.nvim",
		cmd = {
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewFileHistory",
			"DiffviewFocusFiles",
			"DiffviewToggleFiles",
			"DiffviewRefresh",
		},
		opts = {
			view = {
				merge_tool = {
					layout = "diff3_horizontal",
				},
			},
		},
	},
	{
		"DrKJeff16/project.nvim",
		tag = "v6.0.2-1",
		event = "VeryLazy",
		config = function()
			require("project").setup({})
			require("telescope").load_extension("projects")
		end,
	},
}
