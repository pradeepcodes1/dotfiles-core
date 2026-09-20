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
	end,
}
