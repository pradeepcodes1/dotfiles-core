-- make the language-server set reproducible while preferring system clangd.
--
-- Everything below used to run while lazy was *collecting* specs -- requiring
-- lsp.common (which calls vim.diagnostic.config), registering LspAttach, and
-- declaring/enabling servers -- rather than when this plugin loads. It worked,
-- but it made LSP setup an invisible side effect of reading a file. init()
-- takes what has to exist before any server attaches; config() takes the rest.
local paths = require("core.paths")

local function first_executable(candidates)
	for _, candidate in ipairs(candidates) do
		if candidate ~= "" and vim.fn.executable(candidate) == 1 then
			return candidate
		end
	end

	return "clangd"
end

local function clangd_cmd()
	local clangd_bin = first_executable({
		paths.homebrew("opt/llvm/bin/clangd"),
		"/usr/bin/clangd",
		vim.fn.exepath("clangd"),
		vim.fn.stdpath("data") .. "/mason/bin/clangd",
	})

	local query_drivers = {
		paths.homebrew("opt/llvm/bin/clang++"),
		paths.homebrew("opt/llvm/bin/clang"),
		paths.application("Xcode", "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"),
		paths.application("Xcode", "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"),
		"/usr/bin/clang++",
		"/usr/bin/clang",
	}

	return {
		clangd_bin,
		"--background-index",
		"--query-driver=" .. table.concat(query_drivers, ","),
	}
end

local function show_ts_references(command, ctx)
	local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
	local arguments = command.arguments or {}
	local file_uri, position, locations = arguments[1], arguments[2], arguments[3]
	local references = require("core.references")
	local quickfix_items = vim.lsp.util.locations_to_items(locations or {}, client.offset_encoding)

	vim.lsp.util.show_document({
		uri = file_uri,
		range = {
			start = position,
			["end"] = position,
		},
	}, client.offset_encoding)

	references.open_items(quickfix_items, command.title)
end

return {
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
		-- Diagnostic display and the attach hook have to be in place before the
		-- first server attaches, which can happen before this plugin loads.
		init = function()
			local common = require("lsp.common")
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					if client then
						common.on_attach(client, ev.buf)
						if client.name == "jdtls" then
							require("lsp.java").on_attach(ev.buf)
						end
					end
				end,
			})
		end,
		config = function()
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			})

			vim.lsp.config("ts_ls", {
				commands = {
					["editor.action.showReferences"] = show_ts_references,
				},
			})

			vim.lsp.config("clangd", {
				cmd = clangd_cmd(),
				root_markers = {
					".clangd",
					".clang-tidy",
					".clang-format",
					"compile_commands.json",
					"compile_flags.txt",
					"configure.ac",
					"CMakeLists.txt",
					"CMakePresets.json",
					".git",
				},
			})

			-- clangd is intentionally not in ensure_installed (we prefer the system
			-- binary), so mason-lspconfig's automatic_enable never sees it as
			-- "installed" and skips it.
			vim.lsp.enable("clangd")

			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"lua_ls",
					"gopls",
					"rust_analyzer",
					"pyright",
					"kotlin_language_server",
					"jsonls",
					"taplo",
					"yamlls",
					"marksman",
					"tailwindcss",
					"lemminx",
				},
				automatic_enable = {
					exclude = { "jdtls" },
				},
			})
		end,
	},
}
