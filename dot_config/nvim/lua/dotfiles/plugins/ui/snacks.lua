return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	init = function()
		vim.api.nvim_create_autocmd("BufWinEnter", {
			callback = function(event)
				if vim.bo[event.buf].filetype ~= "snacks_picker_input" then
					return
				end

				-- Picker windows inherit line numbers before Snacks applies its minimal style.
				vim.wo.number = false
				vim.wo.relativenumber = false
			end,
		})

		-- Snacks uses its filetype as the persistent scratch extension. Keep
		-- the files as .md, then normalize the buffer to Neovim's canonical
		-- markdown filetype when it opens.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "md",
			callback = function(event)
				vim.bo[event.buf].filetype = "markdown"
			end,
		})

		-- The dashboard is a menu, so hide the block cursor Snacks parks on the
		-- selected key. A cursor highlight with blend=100 makes the TUI hide the
		-- cursor (:h tui-cursor-shape). Normal mode only, so `:` still shows one.
		-- The entry is appended and removed rather than saving/restoring the whole
		-- option, because smear-cursor splices its own hide group into guicursor
		-- the same way and a stale restore would clobber it.
		local hidden_cursor = ",n:block-DashboardHiddenCursor"
		-- One idempotent check of the current buffer replaces the separate
		-- hide-on-enter and show-on-leave handlers: entering any other buffer
		-- brings the cursor back.
		local function sync_dashboard_cursor()
			local hide = vim.bo.filetype == "snacks_dashboard" and vim.bo.buftype ~= "terminal"
			local current = vim.o.guicursor
			local present = current:find(hidden_cursor, 1, true) ~= nil
			-- Re-set even when the entry is already in guicursor: a colorscheme
			-- switch on the dashboard clears the group while the entry stays.
			if hide then
				vim.api.nvim_set_hl(0, "DashboardHiddenCursor", { blend = 100, nocombine = true })
			end
			if hide ~= present then
				vim.o.guicursor = hide and current .. hidden_cursor or current:gsub(vim.pesc(hidden_cursor), "")
			end
		end
		-- ColorScheme too, so `:colorscheme` run from the dashboard re-hides it.
		vim.api.nvim_create_autocmd({ "BufEnter", "ColorScheme" }, {
			desc = "Hide the cursor only while the dashboard is focused",
			callback = sync_dashboard_cursor,
		})
		-- Snacks sets the dashboard filetype under eventignore=all, after the
		-- buffer is already entered, so neither FileType nor that first BufEnter
		-- sees it; its own Opened event covers the first show.
		vim.api.nvim_create_autocmd("User", {
			pattern = "SnacksDashboardOpened",
			desc = "Hide the cursor when the dashboard opens",
			callback = sync_dashboard_cursor,
		})
		-- Snacks closes lazygit and other auto-close terminals from inside its
		-- own TermClose handler, where nested autocmds are off, so landing back
		-- on the dashboard fires no BufEnter. Check once the float is gone.
		vim.api.nvim_create_autocmd("TermClose", {
			desc = "Hide the cursor when a terminal closes back onto the dashboard",
			callback = function()
				vim.schedule(sync_dashboard_cursor)
			end,
		})
	end,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		notifier = {
			enabled = true,
			-- FFF already refuses the unsafe home scan; do not surface that expected refusal.
			filter = function(notification)
				return notification.msg
					~= "FFF: Refusing to index home directory. Set enable_home_dir_scanning = true to override."
			end,
			timeout = 1500,
			width = { min = 10, max = 0.4 },
			icons = {
				trace = "✎ ",
			},
		},
		dashboard = {
			enabled = not vim.g.nvim_preview,
			-- Recent Files rows read relative to the cwd, or the open project.
			formats = {
				file = function(item, ctx)
					return require("dotfiles.ui.dashboard_header").format_file(item, ctx)
				end,
			},
			-- Home and project views live in ui/dashboard.lua; Snacks resolves this
			-- function on every render, so switching views is just an update.
			-- Snacks drops pane 2 below the keys when the window is too narrow.
			sections = {
				function()
					return require("dotfiles.ui.dashboard").sections()
				end,
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
		picker = {
			enabled = true,
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
					-- Dock the sidebar on the right so code keeps the left edge.
					-- Merges into the source's own `preset = "sidebar"`, which
					-- defaults to the left.
					layout = { layout = { position = "right" } },
					actions = {
						close_explorer = function()
							require("dotfiles.ui.explorer").close()
						end,
						-- A single mouse click toggles a folder (files still open on
						-- double-click). Bound to the release so Neovim's native click
						-- has already moved the cursor onto the clicked row; releases
						-- that end outside the list (e.g. after a drag) are ignored.
						explorer_click = function(picker)
							if vim.fn.getmousepos().winid ~= picker.list.win.win then
								return
							end
							local item = picker:current()
							if item and item.dir then
								picker:action("confirm")
							end
						end,
						-- The first click of a double-click already toggled the folder,
						-- so only files react here; otherwise the folder would flip back.
						explorer_double_click = function(picker)
							local item = picker:current()
							if item and not item.dir then
								picker:action("confirm")
							end
						end,
					},
					win = {
						list = {
							keys = {
								["."] = "toggle_ignored",
								q = "close_explorer",
								["<C-q>"] = "close_explorer",
								Q = "close_explorer",
								["<leader>x"] = "close_explorer",
								["<C-w>c"] = "close_explorer",
								["<C-w>q"] = "close_explorer",
								-- Mouse only: keyboard confirm (<CR>/l) is unchanged.
								["<LeftRelease>"] = "explorer_click",
								["<2-LeftMouse>"] = "explorer_double_click",
							},
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
						},
					},
				},
				select = {
					focus = "list",
					layout = {
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
					layout = { preset = "vertical", hidden = { "preview" }, layout = { width = 0.45 } },
				},
			},
		},
		quickfile = { enabled = true },
		-- Replaces neoscroll: Snacks animates every scroll (<C-u>/<C-d>,
		-- <C-b>/<C-f>, zz/zt/zb, the <C-e>/<C-y> maps in keymaps/init.lua)
		-- without per-key mappings. It leaves mouse-wheel scrolls unanimated.
		scroll = {
			enabled = true,
			animate = { duration = { step = 10, total = 150 }, easing = "inOutSine" },
		},
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
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").snacks
	end,
}
