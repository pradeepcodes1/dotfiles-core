-- install parsers centrally for consistent syntax-aware editing.
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
				-- markview.nvim parses buffers with both Markdown parsers.
				"markdown",
				"markdown_inline",
				-- Swift gets the same syntax highlighting, indentation, and text objects as other source files.
				"swift",
				-- Rust projects had no parser, so ]m/[m and af/if crashed there.
				"rust",
				"toml",
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
			})

			local select = require("nvim-treesitter-textobjects.select")
			local move = require("nvim-treesitter-textobjects.move")
			local map = vim.keymap.set
			local function textobject(action, query)
				return function()
					-- Without a parser the plugin scores an empty range and throws;
					-- a missing language should just make the motion a no-op.
					if not vim.treesitter.get_parser(0, nil, { error = false }) then
						return
					end
					action(query, "textobjects")
				end
			end
			-- One row per binding instead of one map() call each; selections work in
			-- visual and operator-pending mode, motions in normal mode too.
			for _, spec in ipairs({
				{ "af", select.select_textobject, "@function.outer", "Around function" },
				{ "if", select.select_textobject, "@function.inner", "Inside function" },
				{ "ac", select.select_textobject, "@class.outer", "Around class" },
				{ "ic", select.select_textobject, "@class.inner", "Inside class" },
				{ "aa", select.select_textobject, "@parameter.outer", "Around parameter" },
				{ "ia", select.select_textobject, "@parameter.inner", "Inside parameter" },
				{ "]m", move.goto_next_start, "@function.outer", "Next function start" },
				{ "]]", move.goto_next_start, "@class.outer", "Next class start" },
				{ "]a", move.goto_next_start, "@parameter.inner", "Next parameter" },
				{ "]M", move.goto_next_end, "@function.outer", "Next function end" },
				{ "][", move.goto_next_end, "@class.outer", "Next class end" },
				{ "[m", move.goto_previous_start, "@function.outer", "Previous function start" },
				{ "[[", move.goto_previous_start, "@class.outer", "Previous class start" },
				{ "[a", move.goto_previous_start, "@parameter.inner", "Previous parameter" },
				{ "[M", move.goto_previous_end, "@function.outer", "Previous function end" },
				{ "[]", move.goto_previous_end, "@class.outer", "Previous class end" },
			}) do
				local lhs, action, query, desc = unpack(spec)
				local modes = action == select.select_textobject and { "x", "o" } or { "n", "x", "o" }
				map(modes, lhs, textobject(action, query), { desc = desc })
			end
		end,
	},
}
