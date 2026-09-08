-- smooth keyboard and wheel movement without letting the cursor drift independently.
return {
	"karb94/neoscroll.nvim",
	event = "VeryLazy",
	config = function()
		local neoscroll = require("neoscroll")
		neoscroll.setup({
			mappings = {},
			cursor_scrolls_alone = false,
			-- Sine eases both ends gently so short wheel and longer keyboard motions blend smoothly.
			easing = "sine",
		})

		-- Register the plugin-specific callbacks from the central binding module.
		require("core.keymaps").neoscroll()
	end,
}
