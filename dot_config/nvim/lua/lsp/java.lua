-- recover Java navigation where jdtls cannot resolve import definitions directly.
-- lua/lsp/java.lua
-- Smart gd/gr for Java: falls back to workspace/symbol search on import lines
-- where jdtls doesn't resolve textDocument/definition.
local M = {}
local references = require("core.references")

--- Detect if the current line is a Java import statement and return the FQCN.
--- Handles regular imports (`import com.example.MyClass;`) and
--- static imports (`import static com.example.MyClass.method;` → `com.example.MyClass`).
--- Returns nil for non-import lines.
local function parse_import_fqcn()
	local line = vim.api.nvim_get_current_line()

	-- Regular import: import com.example.MyClass;
	local fqcn = line:match("^%s*import%s+([%w%.]+)%s*;")
	if fqcn then
		return fqcn
	end

	-- Static import: import static com.example.MyClass.method;
	-- Extract the class portion (everything up to the last dot before the member)
	local static_path = line:match("^%s*import%s+static%s+([%w%.]+)%s*;")
	if static_path then
		-- Remove the last segment (the static member name) to get the class FQCN
		local class_fqcn = static_path:match("^(.+)%.[%w]+$")
		return class_fqcn or static_path
	end

	return nil
end

--- Navigate to a class definition by its FQCN using workspace/symbol search.
local function goto_class_by_fqcn(fqcn)
	if fqcn:match("%*$") then
		vim.notify("Cannot navigate to wildcard import", vim.log.levels.WARN)
		return
	end

	-- Extract simple class name (last segment of FQCN)
	local simple_name = fqcn:match("([%w]+)$")
	if not simple_name then
		vim.notify("Could not parse class name from: " .. fqcn, vim.log.levels.WARN)
		return
	end

	local clients = vim.lsp.get_clients({ bufnr = 0, name = "jdtls" })
	if #clients == 0 then
		vim.notify("jdtls not attached", vim.log.levels.WARN)
		return
	end

	clients[1].request("workspace/symbol", { query = simple_name }, function(err, results)
		if err or not results or #results == 0 then
			vim.notify("No workspace symbol found for: " .. simple_name, vim.log.levels.WARN)
			return
		end

		-- Try exact FQCN match first
		local class_kinds = {
			[5] = true, -- Class
			[11] = true, -- Interface
			[10] = true, -- Enum
		}
		for _, sym in ipairs(results) do
			if class_kinds[sym.kind] then
				local container = sym.containerName or ""
				local sym_fqcn = container ~= "" and (container .. "." .. sym.name) or sym.name
				if sym_fqcn == fqcn then
					local loc = sym.location
					vim.schedule(function()
						vim.lsp.util.show_document(loc, "utf-8", { focus = true })
					end)
					return
				end
			end
		end

		-- Fallback: first class/interface/enum matching simple name
		for _, sym in ipairs(results) do
			if class_kinds[sym.kind] and sym.name == simple_name then
				local loc = sym.location
				vim.schedule(function()
					vim.lsp.util.show_document(loc, "utf-8", { focus = true })
				end)
				return
			end
		end

		vim.notify("No class found for: " .. fqcn, vim.log.levels.WARN)
	end)
end

--- Smart gd: on import lines, tries LSP definition then falls back to workspace/symbol.
local function smart_definition()
	local fqcn = parse_import_fqcn()
	if not fqcn then
		vim.lsp.buf.definition()
		return
	end

	-- Try standard definition first; if it fails, fall back to workspace symbol
	local params = vim.lsp.util.make_position_params(0, "utf-8")
	vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result)
		if not err and result and (not vim.islist(result) or #result > 0) then
			-- Standard definition worked, use default handler
			vim.schedule(function()
				vim.lsp.buf.definition()
			end)
		else
			-- Fall back to workspace symbol search
			goto_class_by_fqcn(fqcn)
		end
	end)
end

--- Smart gr: on import lines, tries LSP references then falls back to Telescope workspace symbols.
local function smart_references()
	local fqcn = parse_import_fqcn()
	if not fqcn then
		references.open_float()
		return
	end

	local simple_name = fqcn:match("([%w]+)$")
	local params = vim.lsp.util.make_position_params(0, "utf-8")
	params.context = { includeDeclaration = true }
	vim.lsp.buf_request(0, "textDocument/references", params, function(err, result)
		if not err and result and #result > 0 then
			vim.schedule(function()
				references.open_float()
			end)
		else
			-- Fall back to Telescope workspace symbols filtered by class name
			vim.schedule(function()
				local ok, builtin = pcall(require, "telescope.builtin")
				if ok then
					builtin.lsp_workspace_symbols({ query = simple_name or "" })
				else
					vim.lsp.buf.workspace_symbol(simple_name or "")
				end
			end)
		end
	end)
end

--- Set buffer-local gd/gr overrides for Java buffers with jdtls.
function M.on_attach(bufnr)
	local function nmap(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "LSP/Java: " .. desc })
	end
	nmap("gd", smart_definition, "[G]oto [D]efinition (import-aware)")
	nmap("gr", smart_references, "[G]oto [R]eferences (import-aware)")
end

return M
