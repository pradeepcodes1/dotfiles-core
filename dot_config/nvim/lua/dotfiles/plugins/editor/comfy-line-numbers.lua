-- label relative lines with left-hand digits only (1..5, 11..55, ...) so a
-- vertical jump keeps the counting hand on the left and j/k on the right.
-- The labels are remapped back to real counts, so 11j still moves 6 lines.
return {
	"mluders/comfy-line-numbers.nvim",

	-- Rendering happens through 'statuscolumn' and the autocmds setup()
	-- installs, so it only has to be loaded once the UI exists.
	event = "VeryLazy",

	-- Defaults already blank the column for terminal and nofile buffers, which
	-- covers terminal buffers, the Snacks explorer, dashboard and Aerial here.
	opts = {},

	config = function(_, opts)
		require("comfy-line-numbers").setup(opts)
		-- setup() runs `vim.opt.relativenumber = true`, which also lands on the
		-- window already on screen. On the startup dashboard (nonumber) that
		-- shows a bare relative column until some enter event clears it.
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if not vim.wo[win].number then
				vim.wo[win].relativenumber = false
			end
		end
	end,
}
