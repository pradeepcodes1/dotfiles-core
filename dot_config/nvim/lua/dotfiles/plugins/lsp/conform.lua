-- format normal source on save while avoiding large or generated files.

-- The prettierd daemon answers in milliseconds; a cold `prettier` pays node's
-- startup on every save and could overrun the save timeout below, which skipped
-- formatting without notice. Plain prettier stays the fallback where the daemon
-- is not installed.
local prettier = { "prettierd", "prettier", stop_after_first = true }

return {
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		-- A function, so importing this spec never loads the key data.
		keys = function()
			return require("dotfiles.keymaps.specs").conform
		end,
		cmd = "ConformInfo",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				-- Pyright's import organizing is off (masonlsp.lua) because Ruff owns it,
				-- so sort imports here before formatting.
				python = { "ruff_organize_imports", "ruff_format" },
				javascript = prettier,
				typescript = prettier,
				-- JSX and TSX have their own filetypes rather than inheriting these entries.
				javascriptreact = prettier,
				typescriptreact = prettier,
				html = prettier,
				css = prettier,
				c = { "clang-format" },
				cpp = { "clang-format" },
				sh = { "shfmt" },
				go = { "gofmt" },
				rust = { "rustfmt" },
				-- Prefer SwiftFormat when installed; Conform's LSP fallback still handles machines without it.
				swift = { "swiftformat" },
				json = prettier,
				-- JSON with comments needs the same formatter as ordinary JSON.
				jsonc = prettier,
				yaml = prettier,
				markdown = prettier,
				toml = { "taplo" },
			},
			format_on_save = function(bufnr)
				-- Manual formatting remains available while automatic formatting is paused.
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
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
				-- Long enough for a cold prettier when the daemon is absent; fast
				-- formatters finish well inside it either way.
				return { timeout_ms = 1500, lsp_format = "fallback" }
			end,
		},
	},
}
