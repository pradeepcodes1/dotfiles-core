return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		spec = {
			{ "<leader>f", group = "Find" },
			-- The f group finds things inside a project; p acts on the project itself.
			{ "<leader>p", group = "Project" },
			{ "<leader>g", group = "Git", mode = { "n", "x" } },
			{ "<leader>h", group = "Hunk", mode = { "n", "x" } },
			{ "<leader>l", group = "LSP", mode = { "n", "x" } },
			{ "<leader>d", group = "Debug", mode = { "n", "x" } },
			{ "<leader>t", group = "Test" },
			{ "<leader>v", group = "View" },
			{ "<leader>w", group = "Window" },
			{ "<leader>u", group = "Toggle" },
		},
	},
}
