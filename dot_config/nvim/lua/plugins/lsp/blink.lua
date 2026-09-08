-- merge LSP and Copilot candidates into one completion UI with deliberate keys.
return {
	"saghen/blink.cmp",
	-- A tagged release so blink fetches its prebuilt fuzzy-matcher binary
	-- instead of needing a Rust toolchain to build one.
	version = "1.*",
	-- No lazy event: plugins/masonlsp.lua takes this plugin's LSP capabilities
	-- at startup, before any server is configured, so it is a dependency there
	-- and loads then. Declaring InsertEnter as well would only be misleading.
	dependencies = {
		{ "fang2hou/blink-copilot", version = "1.*" },
	},
	---@module "blink.cmp"
	---@type blink.cmp.Config
	opts = {
		-- Completion keeps its own API shape while the choices live in the central binding file.
		keymap = require("core.keymaps").blink,
		completion = {
			list = {
				-- Nothing is selected until you move to it, and moving to it
				-- does not rewrite the buffer underneath you.
				selection = { preselect = false, auto_insert = false },
			},
			documentation = { auto_show = true },
		},
		sources = {
			-- Deliberately not blink's default set, which adds `path`,
			-- `snippets` and `buffer`. This config has always completed from
			-- the language server and Copilot only.
			default = { "lsp", "copilot" },
			providers = {
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
