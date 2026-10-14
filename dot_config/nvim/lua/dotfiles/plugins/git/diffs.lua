-- Enhance the full blame popup already opened by the Git-hunk Hydra's b action.
return {
	-- Upstream moved to Forgejo; the GitHub repo is removed on 2026-10-31.
	url = "https://forge.barrettruth.com/barrettruth/diffs.nvim",
	name = "diffs.nvim",
	-- Must be loaded before gitsigns opens a blame popup; same event as gitsigns.
	event = "BufReadPre",
	init = function()
		vim.g.diffs = {
			integrations = { gitsigns = true },
			-- CodeDiff owns conflict review; this addition is for popup highlighting.
			conflict = { enabled = false },
		}
	end,
}
