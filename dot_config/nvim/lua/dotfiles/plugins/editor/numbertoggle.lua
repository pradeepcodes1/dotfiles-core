-- keep relative numbers where they are useful - normal mode in the focused
-- window - and fall back to absolute numbers everywhere else, so an inactive
-- split still shows the real line a message or reviewer refers to.
return {
	"sitiom/nvim-numbertoggle",

	-- The plugin registers its autocmds from plugin/, so it only needs to be
	-- loaded once the UI is up; options.lua already opens on relativenumber.
	event = "VeryLazy",

	config = function()
		-- The plugin turns relative numbers back on from a global 'number'
		-- check, which lands on windows that switched their number column off
		-- for themselves -- the dashboard shows a bare relative column that
		-- way. Registering here runs after plugin/numbertoggle.lua, so this
		-- has the last word on those windows.
		local group = vim.api.nvim_create_augroup("numbertoggle_respect_window", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "WinEnter" }, {
			group = group,
			callback = function()
				if not vim.wo.number then
					vim.wo.relativenumber = false
				end
			end,
		})

		-- The plugin's leave handler forces a synchronous :redraw on every
		-- BufLeave/WinLeave. Snacks builds the explorer split in steps, so that
		-- redraw painted it half-built: a half-width window showing the current
		-- buffer. Only the cmdline needs the forced redraw, to show absolute
		-- numbers while typing a range; everything else repaints on its own.
		vim.api.nvim_clear_autocmds({
			group = "numbertoggle",
			event = { "BufLeave", "WinLeave", "FocusLost", "InsertEnter", "CmdlineEnter" },
		})
		local leave = vim.api.nvim_create_augroup("numbertoggle_leave", { clear = true })
		vim.api.nvim_create_autocmd({ "FocusLost", "InsertEnter" }, {
			group = leave,
			callback = function()
				if vim.o.number then
					vim.opt.relativenumber = false
				end
			end,
		})
		vim.api.nvim_create_autocmd("CmdlineEnter", {
			group = leave,
			callback = function()
				if vim.o.number then
					vim.opt.relativenumber = false
					-- Same guard as the plugin (neovim#32068): no redraw for input() or :insert.
					if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
						vim.cmd("redraw")
					end
				end
			end,
		})
		-- Decide once the event loop settles: nvim_win_call(), which Snacks uses
		-- to build its split, switches windows and back without a WinEnter, so
		-- the window you stay in must keep its relative numbers.
		vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
			group = leave,
			callback = function()
				local win = vim.api.nvim_get_current_win()
				vim.schedule(function()
					if
						vim.api.nvim_win_is_valid(win)
						and win ~= vim.api.nvim_get_current_win()
						and vim.wo[win].number
					then
						vim.wo[win].relativenumber = false
					end
				end)
			end,
		})
	end,
}
