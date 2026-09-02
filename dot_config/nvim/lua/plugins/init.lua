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
				"<leader>>",
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
}
