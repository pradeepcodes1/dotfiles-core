return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- which-key ignores 'winborder' (its default is "none"), so pass it through.
		win = { border = vim.o.winborder },
		spec = {
			{ "<leader>f", group = "Find" },
			{ "<leader>m", group = "Marks" },
			-- Keep project task execution separate from the language-specific test group.
			{ "<leader>o", group = "Overseer" },
			-- The f group finds things inside a project; p acts on the project itself.
			{ "<leader>p", group = "Project" },
			{ "<leader>g", group = "Git", mode = { "n", "x" } },
			-- Visual only: in normal mode <leader>h is a plain key that opens the
			-- hunk mode (ui/modal.lua), whose heads live under their own node.
			{ "<leader>h", group = "Hunk", mode = "x" },
			-- x too: adding a snippet from a visual selection prefills its body.
			{ "<leader>i", group = "Snippets", mode = { "n", "x" } },
			{ "<leader>l", group = "LSP", mode = { "n", "x" } },
			{ "<leader>d", group = "Debug", mode = { "n", "x" } },
			{ "<leader>t", group = "Test" },
			{ "<leader>v", group = "View" },
			-- <leader>w is no longer a group: it opens the resize mode directly.
			{ "<leader>u", group = "Toggle" },
		},
	},
}
