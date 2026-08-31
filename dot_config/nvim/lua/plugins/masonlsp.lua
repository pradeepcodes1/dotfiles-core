-- make the language-server set reproducible while preferring system clangd.
local common = require("lsp.common")
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

	references.open_items_float(quickfix_items, command.title, {
		command = command,
		bufnr = ctx.bufnr,
	})
end

vim.lsp.config("ts_ls", {
	commands = {
		["editor.action.showReferences"] = show_ts_references,
	},
})

-- Set up LSP keymaps via LspAttach autocommand
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

-- clangd is intentionally not in ensure_installed (we prefer the system binary),
-- so mason-lspconfig's automatic_enable never sees it as "installed" and skips it.
vim.lsp.enable("clangd")

return {
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp" },
		config = function()
			vim.lsp.config("*", {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})
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
