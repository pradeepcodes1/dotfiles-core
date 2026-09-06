return {
	"nvim-java/nvim-java",
	ft = "java", -- lazy load only for Java files
	config = function()
		require("java").setup({
			java_test = {
				enable = false,
			},
			java_debug_adapter = {
				enable = false,
			},
			spring_boot_tools = {
				enable = false,
			},
		})
		-- nvim-java names jdtls' Eclipse workspace `sha256(vim.fn.getcwd())`
		-- and never passes the root it already has: get_jdtls_cache_data_path
		-- (java-core/utils/lsp.lua) is called from get_jar_args
		-- (java-core/ls/servers/jdtls/cmd.lua) with no cwd, so the fallback
		-- always wins. Open a Java file while cwd is another project and jdtls
		-- is handed a workspace named after *that* project: nothing imported,
		-- no classpath, and workspace/symbol answers 0 results in 2ms while
		-- documentSymbol still works, so `fs` looks fine and `fS` looks broken.
		-- That is not jdtls being odd -- jdtls defaults `-data` to a temp dir
		-- derived from the cwd, and lspconfig's own jdtls config overrides it
		-- from config.root_dir. nvim-java is the one that does not.
		--
		-- `cmd` is a function invoked at client creation with the resolved
		-- config, so root_dir is available exactly where nvim-java declines to
		-- use it. Swap the path builder for the duration of that one call.
		local java_lsp_utils = require("java-core.utils.lsp")
		local cache_data_path = java_lsp_utils.get_jdtls_cache_data_path
		local build_jdtls_cmd = vim.lsp.config.jdtls and vim.lsp.config.jdtls.cmd

		if type(build_jdtls_cmd) ~= "function" or type(cache_data_path) ~= "function" then
			-- Fail loudly rather than silently reverting to cwd-keyed workspaces.
			vim.notify(
				"nvim-java internals changed: jdtls workspace is no longer pinned to the project root",
				vim.log.levels.WARN
			)
		end

		vim.lsp.config("jdtls", {
			settings = {
				java = {
					symbols = { includeSourceMethodDeclarations = true },
				},
			},
			cmd = (type(build_jdtls_cmd) == "function" and type(cache_data_path) == "function")
					and function(dispatchers, lsp_config)
						java_lsp_utils.get_jdtls_cache_data_path = function(cwd)
							return cache_data_path(lsp_config.root_dir or cwd)
						end
						local ok, client = pcall(build_jdtls_cmd, dispatchers, lsp_config)
						java_lsp_utils.get_jdtls_cache_data_path = cache_data_path
						if not ok then
							error(client)
						end
						return client
					end
				or nil,
			handlers = {
				["$/progress"] = function() end,
				["language/status"] = function() end,
			},
		})
		vim.lsp.enable("jdtls")
	end,
}
