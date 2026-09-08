return {
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
			style = "compact",
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
					-- Let new folders enter project mode before they have a saved session.
					{
						icon = " ",
						key = "o",
						desc = "Open Project",
						action = function()
							require("project.actions.pickers").open_directory()
						end,
					},
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{
						icon = " ",
						key = "r",
						desc = "Recent Files",
						action = function()
							Snacks.picker.recent()
						end,
					},
					{ icon = "", key = "p", desc = "Projects", action = "<leader>pp" },
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
			-- <C-.> is the chord this config used under Telescope. It toggles
			-- *ignored* rather than hidden, matching `.` in the explorer:
			-- hidden is on by default in every file source below, so
			-- gitignored files are the only thing left worth revealing. It
			-- cannot be `.` here the way it is in the explorer -- these
			-- pickers open focused on the input, where a `.` has to stay a
			-- literal character. Snacks' own <a-h>/<a-i> stay bound for both
			-- directions, and <C-.> needs the kitty keyboard protocol to
			-- arrive at all, which Neovim turns on under TERM=xterm-kitty --
			-- <a-i> is the fallback anywhere it does not.
			win = {
				input = { keys = { ["<c-.>"] = { "toggle_ignored", mode = { "i", "n" } } } },
				list = { keys = { ["<c-.>"] = "toggle_ignored" } },
			},
			sources = {
				-- Buffers use Snacks defaults now that Harpoon marks have their own menu.
				-- hidden has to be set per-source: a source's own config merges
				-- *after* the global picker opts (config/init.lua orders them
				-- defaults, user, source, call-site), so a top-level
				-- `hidden = true` would lose to the `hidden = false` Snacks sets
				-- on `files` itself. `grep` declares no default and would take a
				-- global one, but is spelled out so both read the same way. Each
				-- excludes .git on its own (files passes fd -E .git, grep passes
				-- rg --glob=!.git), so this surfaces real dotfiles without the
				-- object store -- 24 files rather than 493, measured in this
				-- repo. `smart` needs no entry: config.multi merges
				-- opts.sources[name] into each leg, so its files leg picks this
				-- up. Deliberately NOT set on `buffers`, where `hidden` is an
				-- unrelated option -- unlisted buffers, not dotfiles.
				grep = { hidden = true },
				explorer = {
					-- Dotfiles are the point of this machine, not an edge case:
					-- a chezmoi source tree is mostly .chezmoi* entries and the
					-- config dirs they render into. Snacks defaults this to false.
					-- Nothing excludes .git in the explorer (unlike the files
					-- source, which hardcodes -E .git), so it shows up here as one
					-- collapsed directory row -- add `exclude = { ".git" }` beside
					-- this if that row ever gets in the way.
					hidden = true,
					actions = {
						close_explorer = function()
							require("ui.explorer").close()
						end,
					},
					win = {
						list = {
							keys = {
								-- Ignored files are the only thing left worth toggling
								-- now that hidden is on by default, so `.` is a second,
								-- more reachable spelling of Snacks' own I. Both stay
								-- bound, as does H for turning hidden back off. List
								-- window only: the explorer's other window is the live
								-- filter prompt, where a `.` has to stay a literal
								-- character. This overrides the Snacks default of
								-- `.` = explorer_focus (set_cwd to the directory under
								-- the cursor), leaving that unbound and its inverse
								-- `<BS>` still in place.
								["."] = "toggle_ignored",
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
				-- windows to leave out. Dotfiles are on -- fd is given
				-- -E .git either way, so a find never opens on .git objects --
				-- and gitignored files stay off until <C-.> asks for them.
				--
				-- This is the only `files` entry in this table. A second one
				-- higher up would not merge with it, it would replace it: Lua
				-- takes the last value for a duplicate key in a constructor.
				files = {
					hidden = true,
					ignored = false,
					layout = { preset = "vertical", hidden = { "preview" }, layout = { width = 0.45 } },
				},
			},
		},
		quickfile = { enabled = true },
		-- Scratch notes are persisted as ordinary files. Mark their buffers so
		-- project-aware features do not treat Snacks' storage directory as the
		-- active project when a scratch window receives focus.
		scratch = { ft = "md", win = { b = { snacks_scratch = true } } },
		scope = { enabled = true },
		-- comfy-line-numbers owns 'statuscolumn': it writes its own label
		-- column per window on every buffer/window enter, which would just
		-- overwrite whatever the Snacks statuscolumn had put there.
		statuscolumn = { enabled = false },
		words = { enabled = true },
		-- Zen darkens two separate things. The float's backdrop shades the
		-- screen behind the window, which is wanted. The `dim` toggle greys
		-- every line outside the cursor's own scope, which is not -- the
		-- buffer keeps its normal highlighting inside the zen column.
		-- `toggles` merges, so git_signs and mini_diff_signs stay hidden as
		-- upstream has them.
		zen = {
			toggles = { dim = false },
		},
	},
	keys = {
		{
			"<leader>z",
			function()
				Snacks.zen()
			end,
			desc = "Toggle Zen Mode",
		},
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
				Snacks.lazygit({ cwd = require("project.paths").current_root() })
			end,
			desc = "Lazygit",
		},
		{
			"<leader>gf",
			function()
				Snacks.picker.git_status({ cwd = require("project.paths").current_root() })
			end,
			desc = "Git changed files",
		},
		{
			"<leader>gp",
			function()
				Snacks.picker.gh_pr({ cwd = require("project.paths").current_root() })
			end,
			desc = "GitHub pull requests",
		},
		{
			"<leader>gi",
			function()
				Snacks.picker.gh_issue({ cwd = require("project.paths").current_root() })
			end,
			desc = "GitHub issues",
		},
	},
}
