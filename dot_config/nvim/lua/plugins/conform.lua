-- format normal source on save while avoiding large or generated files.
return {
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_format" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				c = { "clang-format" },
				cpp = { "clang-format" },
				sh = { "shfmt" },
				go = { "gofmt" },
				rust = { "rustfmt" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				toml = { "taplo" },
			},
			format_on_save = function(bufnr)
				local bufname = vim.api.nvim_buf_get_name(bufnr)
				-- Skip files larger than 1MB
				local ok, stats = pcall(vim.uv.fs_stat, bufname)
				if ok and stats and stats.size > 1024 * 1024 then
					return
				end
				-- Skip generated/minified files
				if bufname:match("%.min%.") or bufname:match("/generated/") or bufname:match("%.lock$") then
					return
				end
				return { timeout_ms = 500, lsp_format = "fallback" }
			end,
		},
	},
}
