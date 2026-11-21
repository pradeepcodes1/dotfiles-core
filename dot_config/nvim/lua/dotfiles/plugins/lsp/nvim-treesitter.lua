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
				-- Cover the web and Kotlin languages already served by the LSP configuration.
				"typescript",
				"tsx",
				"html",
				"css",
				"kotlin",
				"go",
				"proto",
				"mermaid",
				-- markview.nvim parses buffers with both Markdown parsers.
				"markdown",
				"markdown_inline",
				-- markview only renders $…$ / $$…$$ math when it can parse the LaTeX inside.
				"latex",
				-- Swift gets the same syntax highlighting, indentation, and text objects as other source files.
				"swift",
				-- Rust projects had no parser, so ]m/[m and af/if crashed there.
				"rust",
				"toml",
			})

			-- Vim's own indent scripts handle these better than the experimental
			-- treesitter indents on the main branch (dedent after return, block scalars).
			local native_indent = { python = true, yaml = true }
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("dotfiles_treesitter_start", { clear = true }),
				pattern = "*",
				callback = function(args)
					local ok = pcall(vim.treesitter.start, args.buf)
					if not ok then
						return
					end
					-- Every window showing this buffer, not the current one: FileType
					-- also fires for buffers loaded off-screen (session restore, previews).
					for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
						vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					end
					-- Only where the parser ships an indents query; otherwise the
					-- treesitter indentexpr replaces a working ftplugin with nothing.
					local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
					if lang and not native_indent[lang] and vim.treesitter.query.get(lang, "indents") then
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
			-- Swaps reuse the installed textobjects queries and retain dot-repeat support.
			local swap = require("nvim-treesitter-textobjects.swap")
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
			-- Uppercase A swaps arguments; lowercase [a/]a keep navigating between them.
			map("n", "]A", textobject(swap.swap_next, "@parameter.inner"), { desc = "Swap argument with next" })
			map("n", "[A", textobject(swap.swap_previous, "@parameter.inner"), { desc = "Swap argument with previous" })
		end,
	},
}
