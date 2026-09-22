-- surface line provenance inline so routine blame checks need no separate view.
local map = vim.keymap.set

-- Hydra consumes this table itself, but its modal keys are still bindings and
-- belong beside the Hydra they drive.
local function hunk_heads(gitsigns)
	-- Hydra's modal keys belong with the bindings even though Hydra consumes this table itself.
	return {
		-- The hint stays out of the way until it is explicitly requested.
		{
			"?",
			function()
				if _G.Hydra then
					_G.Hydra.hint:show()
				end
			end,
			{ desc = "show help" },
		},
		{
			"j",
			function()
				gitsigns.nav_hunk("next")
			end,
			{ desc = "next" },
		},
		{
			"k",
			function()
				gitsigns.nav_hunk("prev")
			end,
			{ desc = "previous" },
		},
		{ "p", gitsigns.preview_hunk, { desc = "preview" } },
		{
			"b",
			function()
				gitsigns.blame_line({ full = true })
			end,
			{ desc = "blame" },
		},
		{ "s", gitsigns.stage_hunk, { desc = "stage/unstage" } },
		{ "u", gitsigns.undo_stage_hunk, { desc = "undo stage" } },
		{ "r", gitsigns.reset_hunk, { desc = "reset" } },
		{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
		{ "<Esc>", nil, { exit = true, nowait = true, desc = "exit" } },
	}
end

-- Buffer-local: these need the gitsigns handle and the Hydra, which only exist
-- once gitsigns has attached to this buffer.
local function attach_keys(bufnr, gitsigns, hunk_hydra)
	local buf_opts = { buffer = bufnr, silent = true }
	-- Dispatch the shared prefix by tab so ordinary and CodeDiff buffers can coexist.
	map("n", "<leader>h", function()
		if vim.t.codediff_view then
			require("dotfiles.ui.codediff").activate()
		else
			hunk_hydra:activate()
		end
	end, vim.tbl_extend("force", buf_opts, { desc = "Git / CodeDiff hunk navigation", nowait = true }))
	for _, action in ipairs({
		{ "hs", "stage_hunk", "Stage/unstage Git hunk" },
		{ "hr", "reset_hunk", "Discard working-tree hunk changes" },
	}) do
		map("x", "<leader>" .. action[1], function()
			local first, last = vim.fn.line("v"), vim.fn.line(".")
			gitsigns[action[2]]({ math.min(first, last), math.max(first, last) })
		end, vim.tbl_extend("force", buf_opts, { desc = action[3] .. " (selection)" }))
	end
	map("n", "]h", function()
		gitsigns.nav_hunk("next")
	end, vim.tbl_extend("force", buf_opts, { desc = "Next Git hunk" }))
	map("n", "[h", function()
		gitsigns.nav_hunk("prev")
	end, vim.tbl_extend("force", buf_opts, { desc = "Previous Git hunk" }))
	map("n", "<leader>gb", gitsigns.blame, vim.tbl_extend("force", buf_opts, { desc = "Blame current file" }))
end

return {
	{
		"lewis6991/gitsigns.nvim",
		event = "BufReadPre",
		dependencies = { "nvimtools/hydra.nvim" },

		opts = {
			-- Encode staging state in the glyph so it stays readable without relying on subtle colors.
			signs = {
				add = { text = "U+" },
				change = { text = "U~" },
				delete = { text = "U-" },
				topdelete = { text = "U^" },
				changedelete = { text = "U~" },
				untracked = { text = "??" },
			},
			signs_staged = {
				add = { text = "S+" },
				change = { text = "S~" },
				delete = { text = "S-" },
				topdelete = { text = "S^" },
				changedelete = { text = "S~" },
			},
			current_line_blame = true,
			current_line_blame_opts = { delay = 0 },
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				-- Keep hunk review active so navigation and actions need only one leader prefix.
				local hunk_hydra = require("hydra")({
					name = "Git hunks",
					config = {
						buffer = bufnr,
						color = "pink",
						invoke_on_body = true,
						-- Keep hunk navigation focused until the optional help is requested.
						hint = { float_opts = { border = "rounded" }, hide_on_load = true },
					},
					hint = [[
 Git hunks
 _j_: next   _k_: previous   _p_: preview   _b_: blame
 _s_: stage  _u_: undo stage _r_: reset     _q_/_<Esc>_: exit
]],
					heads = hunk_heads(gitsigns),
				})
				attach_keys(bufnr, gitsigns, hunk_hydra)
			end,
		},
	},
}
