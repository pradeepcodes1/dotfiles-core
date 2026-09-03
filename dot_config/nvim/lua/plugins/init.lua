-- keep foundational editor plugins in one load path.
return {
	----------------------------------------
	-- Core UX
	----------------------------------------
	{ "nvim-lua/plenary.nvim" }, -- lua helpers
	{ "nvim-tree/nvim-web-devicons" },
	{ "folke/which-key.nvim", event = "VeryLazy", config = true },

	----------------------------------------
	-- Git & coding aids
	----------------------------------------
	{ "windwp/nvim-autopairs", event = "InsertEnter", config = true },

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
			-- nvim-java names jdtls' Eclipse workspace `sha256(vim.fn.getcwd())`
			-- and never passes the root it already has: get_jdtls_cache_data_path
			-- (java-core/utils/lsp.lua) is called from get_jar_args
			-- (java-core/ls/servers/jdtls/cmd.lua) with no cwd, so the fallback
			-- always wins. Open a Java file while cwd is another project and jdtls
			-- is handed a workspace named after *that* project: nothing imported,
			-- no classpath, and workspace/symbol answers 0 results in 2ms while
			-- documentSymbol still works, so `fs` looks fine and `fS` looks broken.
			-- That is not jdtls being odd -- jdtls defaults `-data` to a temp dir
			-- derived from the cwd, and lspconfig's own jdtls config overrides it
			-- from config.root_dir. nvim-java is the one that does not.
			--
			-- `cmd` is a function invoked at client creation with the resolved
			-- config, so root_dir is available exactly where nvim-java declines to
			-- use it. Swap the path builder for the duration of that one call.
			local java_lsp_utils = require("java-core.utils.lsp")
			local cache_data_path = java_lsp_utils.get_jdtls_cache_data_path
			local build_jdtls_cmd = vim.lsp.config.jdtls and vim.lsp.config.jdtls.cmd

			if type(build_jdtls_cmd) ~= "function" or type(cache_data_path) ~= "function" then
				-- Fail loudly rather than silently reverting to cwd-keyed workspaces.
				vim.notify(
					"nvim-java internals changed: jdtls workspace is no longer pinned to the project root",
					vim.log.levels.WARN
				)
			end

			vim.lsp.config("jdtls", {
				cmd = (type(build_jdtls_cmd) == "function" and type(cache_data_path) == "function")
						and function(dispatchers, lsp_config)
							java_lsp_utils.get_jdtls_cache_data_path = function(cwd)
								return cache_data_path(lsp_config.root_dir or cwd)
							end
							local ok, client = pcall(build_jdtls_cmd, dispatchers, lsp_config)
							java_lsp_utils.get_jdtls_cache_data_path = cache_data_path
							if not ok then
								error(client)
							end
							return client
						end
					or nil,
				handlers = {
					["$/progress"] = function() end,
					["language/status"] = function() end,
				},
			})
			vim.lsp.enable("jdtls")
		end,
	},

	{ "neovim/nvim-lspconfig" },

	----------------------------------------
	-- Python specifics
	----------------------------------------
	{ "linux-cultist/venv-selector.nvim", cmd = "VenvSelect", opts = { search_venv_managers = false } },

	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		init = function()
			-- Snacks uses its filetype as the persistent scratch extension. Keep
			-- the files as .md, then normalize the buffer to Neovim's canonical
			-- markdown filetype when it opens.
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "md",
				callback = function(event)
					vim.bo[event.buf].filetype = "markdown"
				end,
			})
		end,
		---@type snacks.Config
		opts = {
			bigfile = { enabled = true },
			notifier = {
				enabled = true,
				timeout = 1500,
				width = { min = 10, max = 0.4 },
				style = "minimal",
				top_down = true,
				icons = {
					error = " ",
					warn = " ",
					info = " ",
					debug = " ",
					trace = "✎ ",
				},
			},
			dashboard = {
				enabled = not vim.g.nvim_preview,
				preset = {
					keys = {
						{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
						{
							icon = " ",
							key = "r",
							desc = "Recent Files",
							action = function()
								Snacks.picker.recent()
							end,
						},
						{ icon = "", key = "p", desc = "Projects", action = "<leader>p" },
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
				},
				sections = {
					{ section = "keys", gap = 1, padding = 1 },
				},
			},
			explorer = {
				enabled = not vim.g.nvim_preview,
				replace_netrw = false,
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
			-- Writes a lazygit theme from the active colorscheme, so the float
			-- follows a `theme` switch like everything else here does.
			lazygit = { configure = true },
			picker = {
				enabled = true,
				ui_select = true,
				-- Snacks binds toggle_hidden to <a-h>; <C-.> is the chord this
				-- config used under Telescope. Both reach the same action, in
				-- every picker that supports it. <C-.> needs the kitty keyboard
				-- protocol to arrive at all, which Neovim turns on under
				-- TERM=xterm-kitty -- <a-h> is the fallback anywhere it does not.
				win = {
					input = { keys = { ["<c-.>"] = { "toggle_hidden", mode = { "i", "n" } } } },
					list = { keys = { ["<c-.>"] = "toggle_hidden" } },
				},
				sources = {
					explorer = {
						actions = {
							close_explorer = function()
								require("core.snacks_explorer").close()
							end,
						},
						win = {
							list = {
								keys = {
									["q"] = "close_explorer",
									["<C-q>"] = "close_explorer",
									["Q"] = "close_explorer",
									["<leader>x"] = "close_explorer",
									["<C-w>c"] = "close_explorer",
									["<C-w>q"] = "close_explorer",
								},
							},
						},
					},
					select = {
						focus = "list",
						layout = {
							preset = "select",
							layout = {
								width = 0.35,
								min_width = 48,
								max_width = 68,
								height = 4,
								min_height = 4,
							},
						},
					},
					-- A file list is read by its names, not its contents; the
					-- preview only narrows the column the names live in.
					--
					-- The two `hidden` keys here are unrelated: the source-level
					-- one is dotfiles, the layout-level one is which picker
					-- windows to leave out. Dotfiles stay off until <C-.> asks
					-- for them, so a find never opens on .git objects.
					files = {
						hidden = false,
						ignored = false,
						layout = { preset = "vertical", hidden = { "preview" }, layout = { width = 0.45 } },
					},
				},
			},
			quickfile = { enabled = true },
			scratch = { ft = "md" },
			scope = { enabled = true },
			-- comfy-line-numbers owns 'statuscolumn': it writes its own label
			-- column per window on every buffer/window enter, which would just
			-- overwrite whatever the Snacks statuscolumn had put there.
			statuscolumn = { enabled = false },
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
				"<leader>>",
				function()
					Snacks.scratch.select()
				end,
				desc = "Select Scratch Buffer",
			},
			-- Git. Rooted on the project when there is one; current_root() falls
			-- back to the buffer's own root outside project mode, so these work
			-- anywhere rather than being silent no-ops like the Kitty tools.
			{
				"<leader>gg",
				function()
					Snacks.lazygit({ cwd = require("core.project").current_root() })
				end,
				desc = "Lazygit",
			},
			{
				"<leader>gp",
				function()
					Snacks.picker.gh_pr({ cwd = require("core.project").current_root() })
				end,
				desc = "GitHub pull requests",
			},
			{
				"<leader>gi",
				function()
					Snacks.picker.gh_issue({ cwd = require("core.project").current_root() })
				end,
				desc = "GitHub issues",
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
}
