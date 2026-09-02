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
		keymap = {
			-- `enter` rather than `default`: <CR> accepts, and with preselect
			-- off below it only does so once something is explicitly selected,
			-- which is what cmp.mapping.confirm({ select = false }) meant here.
			preset = "enter",
			-- The home-row pair this config has always used. <C-k> is blink's
			-- show_signature in every preset, so it has to be reclaimed.
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			-- Present in blink's `default` preset but not in `enter`.
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
