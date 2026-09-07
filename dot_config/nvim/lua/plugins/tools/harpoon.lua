-- Keep a small, persistent working set without competing with buffer or split navigation.
return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	enabled = not vim.g.nvim_preview,
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon:setup({
			settings = {
				sync_on_ui_close = true,
			},
		})
		harpoon:extend(require("harpoon.extensions").builtins.highlight_current_file())
	end,
	keys = function()
		local keys = {
			{
				"<leader>m",
				function()
					require("harpoon"):list():add()
				end,
				desc = "Marks: Add current file",
			},
			{
				"<leader>mm",
				function()
					local harpoon = require("harpoon")
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "Marks: Open Harpoon menu",
			},
			{
				"<leader>mp",
				function()
					require("harpoon"):list():prev()
				end,
				desc = "Marks: Previous file",
			},
			{
				"<leader>mn",
				function()
					require("harpoon"):list():next()
				end,
				desc = "Marks: Next file",
			},
			{
				"<leader><leader>",
				function()
					-- Double leader keeps the combined buffer list quick without consuming Ctrl-I/Tab.
					require("ui.harpoon_buffers").open()
				end,
				desc = "Find buffers",
			},
		}

		for index = 1, 9 do
			local slot = index
			table.insert(keys, {
				"<leader>" .. slot,
				function()
					require("harpoon"):list():select(slot)
				end,
				desc = "Harpoon: Go to file " .. slot,
			})
		end

		return keys
	end,
}
