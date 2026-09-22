-- suppress routine LSP chatter so notifications stay reserved for actionable messages.
-- Noice is the router here; Snacks renders. Noice's `notify` view resolves its
-- backend to `{ "snacks", "notify" }` and nvim-notify is not installed, so every
-- surviving message is drawn by the Snacks notifier configured in plugins/ui/snacks.lua.
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	opts = {
		presets = {
			-- The Snacks notifier is compact and times out in 1.5s, which
			-- loses anything tall: stack traces, LSP error blobs, :lua output.
			-- Send those to a scrollable, yankable split instead.
			long_message_to_split = true,
			cmdline_output_to_split = true,
			-- K is mapped to vim.lsp.buf.hover and Noice owns that view; the
			-- default float is borderless against the base16 background.
			lsp_doc_border = true,
		},
		-- blink.cmp drives cmdline completion itself, so Neovim never emits the
		-- popupmenu events this would render. Off to keep the nui views unloaded.
		popupmenu = { enabled = false },
		lsp = {
			-- Progress is a separate channel from the `kind = "message"` route
			-- below, and its `mini` view draws bottom-right while the Snacks
			-- notifier is top-right. jdtls is the noisy producer.
			progress = { enabled = false },
		},
		routes = {
			{
				filter = {
					event = "notify",
					find = "No results from textDocument/documentSymbol",
				},
				opts = { skip = true },
			},
			{
				filter = {
					event = "lsp",
					kind = "message",
				},
				opts = { skip = true },
			},
			-- Snacks pickers close themselves and warn when a finder comes back
			-- empty ("No results found for `todo_comments`" on <leader>ft, and
			-- the same for files/grep). That is the only feedback the picker
			-- gives, so it has to outrank the blanket warning skip below --
			-- routes are matched in order and the first match stops the search.
			{
				filter = {
					event = "notify",
					find = "^No results",
				},
				view = "notify",
			},
			-- Scoped to Neovim's own warning messages. This used to match
			-- `warning = true` alone, which also swallowed every deliberate
			-- vim.notify(..., WARN) in this config (core/yank.lua, lsp/java,
			-- project/actions) -- those were never reaching the screen. If a
			-- specific warning gets noisy again, add a `find` route above this
			-- one rather than widening it back.
			{
				filter = {
					event = "msg_show",
					warning = true,
				},
				opts = { skip = true },
			},
		},
	},
}
