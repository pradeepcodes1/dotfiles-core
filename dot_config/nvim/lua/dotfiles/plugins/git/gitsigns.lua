-- surface line provenance inline so routine blame checks need no separate view.
local map = vim.keymap.set

-- The <leader>h mode's heads, beside the gitsigns actions they drive. A
-- which-key mode (ui/modal.lua) replaces the per-buffer Hydra: the heads act on
-- whichever buffer is current, so one mode serves every attached buffer.
local hunk_mode = require("dotfiles.ui.modal").new("<F35>", "Git hunks", function()
	local gitsigns = require("gitsigns")
	return {
		{
			"j",
			function()
				gitsigns.nav_hunk("next")
			end,
			desc = "next",
		},
		{
			"k",
			function()
				gitsigns.nav_hunk("prev")
			end,
			desc = "previous",
		},
		{ "p", gitsigns.preview_hunk, desc = "preview" },
		{
			"b",
			function()
				gitsigns.blame_line({ full = true })
			end,
			desc = "blame",
		},
		{ "s", gitsigns.stage_hunk, desc = "stage/unstage" },
		{ "u", gitsigns.undo_stage_hunk, desc = "undo stage" },
		{ "r", gitsigns.reset_hunk, desc = "reset" },
	}
end)

-- Buffer-local: these need the gitsigns handle, which only exists once
-- gitsigns has attached to this buffer.
local function attach_keys(bufnr, gitsigns)
	local buf_opts = { buffer = bufnr, silent = true }
	-- Dispatch the shared prefix by tab so ordinary and CodeDiff buffers can coexist.
	map("n", "<leader>h", function()
		if vim.t.codediff_view then
			require("dotfiles.ui.codediff").activate()
		else
			hunk_mode()
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
		init = function()
			-- The blame sidebar has one row per source line, so plain j/k crawl
			-- through a commit's │ rows. Jump between commit headers instead;
			-- gitsigns starts each block with ┍ (or ╺ for a one-line block).
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("dotfiles_gitsigns_blame", { clear = true }),
				pattern = "gitsigns-blame",
				desc = "j/k jump between commits in blame sidebar",
				callback = function(args)
					local function jump(flags)
						return function()
							for _ = 1, vim.v.count1 do
								if vim.fn.search([[^\(┍\|╺\)]], flags) == 0 then
									break
								end
							end
						end
					end
					local opts = { buffer = args.buf, silent = true }
					map("n", "j", jump("W"), vim.tbl_extend("force", opts, { desc = "Next blame commit" }))
					map("n", "k", jump("bW"), vim.tbl_extend("force", opts, { desc = "Previous blame commit" }))
				end,
			})
		end,

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
				-- The hunk mode is shared (see hunk_mode above); only the keys are per buffer.
				attach_keys(bufnr, require("gitsigns"))
			end,
		},
	},
}
