-- Enhance the full blame popup already opened by the Git-hunk Hydra's b action.
return {
	"barrettruth/diffs.nvim",
	lazy = false,
	init = function()
		vim.g.diffs = {
			integrations = { gitsigns = true },
			-- CodeDiff owns conflict review; this addition is for popup highlighting.
			conflict = { enabled = false },
		}
	end,
}
