-- install parsers centrally for consistent syntax-aware editing.
---@module "lazy"
---@type LazySpec
return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").install({
				"lua",
				"cpp",
				"python",
				"java",
				"json",
				"yaml",
				"bash",
				"javascript",
				"go",
				"proto",
				"mermaid",
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function(args)
					local ok = pcall(vim.treesitter.start, args.buf)
					if ok then
						vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
						vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		init = function()
			vim.g.no_plugin_maps = true
		end,
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = {
					lookahead = true,
				},
				move = {
					set_jumps = true,
				},
			})

			local select = require("nvim-treesitter-textobjects.select")
			local move = require("nvim-treesitter-textobjects.move")
			local function textobject(action, query)
				return function()
					action(query, "textobjects")
				end
			end

			local map = vim.keymap.set
			local select_modes = { "x", "o" }
			map(select_modes, "af", textobject(select.select_textobject, "@function.outer"))
			map(select_modes, "if", textobject(select.select_textobject, "@function.inner"))
			map(select_modes, "ac", textobject(select.select_textobject, "@class.outer"))
			map(select_modes, "ic", textobject(select.select_textobject, "@class.inner"))
			map(select_modes, "aa", textobject(select.select_textobject, "@parameter.outer"))
			map(select_modes, "ia", textobject(select.select_textobject, "@parameter.inner"))

			local move_modes = { "n", "x", "o" }
			map(move_modes, "]m", textobject(move.goto_next_start, "@function.outer"))
			map(move_modes, "]]", textobject(move.goto_next_start, "@class.outer"))
			map(move_modes, "]a", textobject(move.goto_next_start, "@parameter.inner"))
			map(move_modes, "]M", textobject(move.goto_next_end, "@function.outer"))
			map(move_modes, "][", textobject(move.goto_next_end, "@class.outer"))
			map(move_modes, "[m", textobject(move.goto_previous_start, "@function.outer"))
			map(move_modes, "[[", textobject(move.goto_previous_start, "@class.outer"))
			map(move_modes, "[a", textobject(move.goto_previous_start, "@parameter.inner"))
			map(move_modes, "[M", textobject(move.goto_previous_end, "@function.outer"))
			map(move_modes, "[]", textobject(move.goto_previous_end, "@class.outer"))
		end,
	},
}
