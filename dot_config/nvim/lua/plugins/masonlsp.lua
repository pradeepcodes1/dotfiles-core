-- make the language-server set reproducible while preferring system clangd.
--
-- Everything below used to run while lazy was *collecting* specs -- requiring
-- lsp.common (which calls vim.diagnostic.config), registering LspAttach, and
-- declaring/enabling servers -- rather than when this plugin loads. It worked,
-- but it made LSP setup an invisible side effect of reading a file. init()
-- takes what has to exist before any server attaches; config() takes the rest.
local paths = require("core.paths")

-- cmd[1] is the bare name: vim.lsp resolves it through PATH, and PATH already
-- answers /usr/bin/clangd -- an xcode-select shim onto the Xcode toolchain on
-- macOS, the distro package on Linux. An earlier version pinned that absolute
-- path with an executable() guard, which turned out to defend nothing: the two
-- spellings name the same binary (measured, exepath("clangd") in nvim), nothing
-- shadows it (mason.lua sets Mason's PATH mode to "append", not its "prepend"
-- default), /usr/bin is in the LaunchServices PATH a GUI Neovide inherits, and
-- when clangd is absent entirely both branches fall back to the same failing
-- spawn. Homebrew's keg-only llvm led the list before that, so the editor ran a
-- clangd the shell could not find by name; at C++20 it bought nothing.
--
-- --query-driver is an allow-list of globs matched against the compiler named
-- in compile_commands.json, not a driver to run, so one glob per prefix covers
-- clang, clang++ and versioned names alike.
local function clangd_cmd()
	local xcode_clang =
		paths.application("Xcode", "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang*")

	return {
		"clangd",
		"--background-index",
		"--query-driver=" .. xcode_clang .. ",/usr/bin/clang*",
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
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
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

			-- Neither of these is in ensure_installed, and automatic_enable only walks
			-- Mason's *installed packages*, so it never sees either one and skips both.
			-- clangd prefers the system binary; rust_analyzer comes from the rustup
			-- toolchain, pinned as a component in mise. A Mason copy of it would never
			-- be reached anyway: lspconfig spawns a bare `rust-analyzer` and Mason's bin
			-- is appended to PATH, so ~/.cargo/bin resolves first.
			vim.lsp.enable("clangd")
			vim.lsp.enable("rust_analyzer")

			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"lua_ls",
					"gopls",
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
