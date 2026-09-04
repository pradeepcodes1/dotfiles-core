-- smooth keyboard and wheel movement without letting the cursor drift independently.
return {
	"karb94/neoscroll.nvim",
	event = "VeryLazy",
	config = function()
		local neoscroll = require("neoscroll")
		neoscroll.setup({
			mappings = {},
			cursor_scrolls_alone = false,
			easing = "quadratic",
		})

		local function scroll(lines, move_cursor, duration)
			return function()
				neoscroll.scroll(lines, { move_cursor = move_cursor, duration = duration })
			end
		end

		local function action(name, duration, duration_key)
			return function()
				neoscroll[name]({ [duration_key or "duration"] = duration })
			end
		end

		local mappings = {
			["<ScrollWheelUp>"] = scroll(-5, true, 100),
			["<ScrollWheelDown>"] = scroll(5, true, 100),
			["<C-u>"] = action("ctrl_u", 150),
			["<C-d>"] = action("ctrl_d", 150),
			["<C-b>"] = action("ctrl_b", 250),
			["<C-f>"] = action("ctrl_f", 250),
			["<C-y>"] = scroll(-0.1, false, 50),
			["<C-e>"] = scroll(0.1, false, 50),
			zt = action("zt", 100, "half_win_duration"),
			-- No `zz`: core/keymaps.lua takes it for the fold toggle. Builtin
			-- `z.` and `z<CR>` still center the cursor line -- unanimated, since
			-- neoscroll only wraps the keys listed here -- and visual-mode `zz`
			-- keeps the builtin centering, which the fold map does not shadow.
			zb = action("zb", 100, "half_win_duration"),
		}

		for lhs, callback in pairs(mappings) do
			vim.keymap.set({ "n", "v" }, lhs, callback)
		end
	end,
}
