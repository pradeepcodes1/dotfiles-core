-- Load Overseer only when its task commands are used so ordinary editing stays lightweight.
return {
	"stevearc/overseer.nvim",
	enabled = not vim.g.nvim_preview,
	cmd = {
		"OverseerClose",
		"OverseerOpen",
		"OverseerRun",
		"OverseerShell",
		"OverseerTaskAction",
		"OverseerToggle",
	},
	-- A function, so importing this spec never loads the key data.
	keys = function()
		return require("dotfiles.keymaps.specs").overseer
	end,
	opts = function(_, opts)
		-- Preserve the plugin's lifecycle components while parsing compiler output in the task's cwd.
		opts.component_aliases = opts.component_aliases or {}
		local components =
			vim.deepcopy(opts.component_aliases.default or require("overseer.config").component_aliases.default)
		table.insert(components, {
			"on_output_quickfix",
			-- Collect complete multiline diagnostics and open failures without stealing focus.
			open_on_exit = "failure",
			items_only = true,
			tail = false,
			focus = false,
		})
		opts.component_aliases.default = components
	end,
}
