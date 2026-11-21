-- Match each file's existing indent style (tabs vs spaces, width) per buffer;
-- inconclusive files keep the 4-space defaults from core/options.lua.
return {
	"NMAC427/guess-indent.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		-- A project's .editorconfig stays authoritative over the heuristic.
		override_editorconfig = false,
		filetype_exclude = { "netrw", "tutor", "snacks_dashboard", "lazy", "mason" },
		buftype_exclude = { "help", "nofile", "terminal", "prompt" },
	},
}
