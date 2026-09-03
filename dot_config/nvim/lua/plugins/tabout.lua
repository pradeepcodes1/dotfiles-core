-- leave a closing bracket or quote with Tab rather than an arrow key or Escape.
return {
	"abecodes/tabout.nvim",
	event = "InsertEnter",
	-- It walks the tree for the enclosing pair, but only through core
	-- `vim.treesitter` calls (get_parser / get_node_text), never the
	-- nvim-treesitter module API -- so the `main` branch this config runs is
	-- fine, despite the plugin predating it.
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	opts = {
		-- tabout's `completion` path rewrites its own binding as
		-- `!pumvisible() ? <Plug>(Tabout) : <the old rhs>`. That is nvim-cmp
		-- era and wrong twice over here: blink draws its menu in a floating
		-- window, where `pumvisible()` is always 0, and blink's keymaps are
		-- buffer-local (nvim_buf_set_keymap in keymap/apply.lua), so tabout's
		-- global `get_rhs` scan would find nothing to preserve anyway.
		--
		-- Off, tabout registers a plain global `i <Tab> <Plug>(Tabout)` and the
		-- two layers stack by scope instead: blink's buffer-local map wins the
		-- key, its `enter` preset runs { "snippet_forward", "fallback" }, and
		-- the fallback resolves the global mapping and returns its rhs. Measured
		-- on blink v1.10.2 -- the `<Plug>` does fire from that expr/noremap
		-- return, and no literal tab leaks through behind it.
		completion = false,
		-- `act_as_tab` keeps a Tab a Tab when there is nothing to step out of.
		-- Its sibling `default_tab = "<C-t>"` never fires -- forward_tab() tests
		-- an undefined `prev_char`, so the plain <Tab> branch always wins -- and
		-- a plain Tab is what belongs there regardless.
		act_as_tab = true,
	},
}
