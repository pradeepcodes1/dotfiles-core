-- merge LSP and Copilot candidates into one completion UI with deliberate keys.
return {
	"saghen/blink.cmp",
	-- A tagged release so blink fetches its prebuilt fuzzy-matcher binary
	-- instead of needing a Rust toolchain to build one.
	version = "1.*",
	-- No lazy event: plugins/lsp/masonlsp.lua takes this plugin's LSP capabilities
	-- at startup, before any server is configured, so it is a dependency there
	-- and loads then. Declaring InsertEnter as well would only be misleading.
	dependencies = {
		{ "fang2hou/blink-copilot", version = "1.*" },
	},
	opts = {
		-- Completion-menu keys are internal to blink, not part of the global layer.
		keymap = {
			preset = "enter",
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},
		completion = {
			list = {
				-- Nothing is selected until you move to it, and moving to it
				-- does not rewrite the buffer underneath you.
				selection = { preselect = false, auto_insert = false },
			},
			documentation = { auto_show = true },
		},
		sources = {
			-- Deliberately not blink's default set, which also adds `path` and
			-- `buffer`. Completion here is the language server, Copilot, and
			-- the hand-written snippets under <config>/snippets.
			default = { "lsp", "copilot", "snippets" },
			providers = {
				snippets = {
					opts = {
						-- No friendly-snippets dependency: this provider reads
						-- only what is checked in under `search_paths`. Left at
						-- its default `true`, blink would scan every runtime
						-- path for a `friendly.snippets` directory on every
						-- reload and find nothing.
						friendly_snippets = false,
						-- The blink default, spelled out because nvim-scissors
						-- (plugins/editor/scissors.lua) writes to the same
						-- directory and the two have to agree.
						search_paths = { vim.fn.stdpath("config") .. "/snippets" },
					},
				},
				copilot = {
					name = "copilot",
					module = "blink-copilot",
					async = true,
					-- Copilot returns long multi-line strings, which fuzzy-match
					-- poorly against a short prefix and would otherwise rank
					-- below every LSP symbol. This is the knob to lower if
					-- Copilot starts crowding the menu.
					score_offset = 100,
				},
			},
		},
	},
}
