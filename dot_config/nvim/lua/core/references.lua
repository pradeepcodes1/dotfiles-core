-- search references in Telescope, then hand the survivors to the Trouble tree float.
local M = {}

local QFLIST_MODE = "references_qflist_float"
local trouble_float = require("core.trouble_float")

local function normalize_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	return vim.fs.normalize(path)
end

local function is_path_under_root(path, root)
	path = normalize_path(path)
	root = normalize_path(root)
	if not path or not root then
		return false
	end

	return path == root or vim.startswith(path, root .. "/")
end

-- LSP servers index more than the project itself. jdtls, for example, returns
-- jdt:// virtual class files and attached JDK/dependency sources for references.
-- Keep the roots from every client attached to the source buffer so `gr` means
-- references in the active workspace, even in a multi-root workspace.
local function workspace_roots(bufnr)
	local roots = {}

	local function add(root)
		root = normalize_path(root)
		if root then
			roots[root] = true
		end
	end

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local folders = client.workspace_folders or (client.config and client.config.workspace_folders)
		for _, folder in ipairs(type(folders) == "table" and folders or {}) do
			if folder.uri then
				local ok, path = pcall(vim.uri_to_fname, folder.uri)
				if ok then
					add(path)
				end
			end
		end

		add(client.root_dir)
		if client.config then
			add(client.config.root_dir)
		end
	end

	if vim.tbl_isempty(roots) then
		add(vim.uv.cwd() or vim.fn.getcwd())
	end

	return roots
end

local function location_is_in_workspace(location, roots)
	local uri = location.uri or location.targetUri
	-- Reference results outside file:// include jdtls' jdt:// decompiled classes.
	if type(uri) ~= "string" or not vim.startswith(uri, "file:") then
		return false
	end

	local ok, path = pcall(vim.uri_to_fname, uri)
	if not ok then
		return false
	end

	for root in pairs(roots) do
		if is_path_under_root(path, root) then
			return true
		end
	end

	return false
end

-- Fractions, not absolute columns: entry_display resolves a width below 1
-- against the live results window, and that window is only ~54 columns at a
-- 120-column editor -- fixed widths ate the whole row and left nothing for the
-- snippet, which is the part worth reading.
-- one location column, not a filename column plus a directory column: fixed
-- fractions pad every short value out to the full width, and Go package dirs
-- ("miner", "blsync") left a gulf of whitespace on every row.
local LOCATION_WIDTH = 0.45

-- Columns instead of gen_from_quickfix's flat "path:lnum:col:text", so the
-- position and the code start at the same offset on every row.
local function reference_entry_maker(opts)
	local make_entry = require("telescope.make_entry")
	-- already the callable, not a factory: utils wraps it in load_once
	local devicon = require("telescope.utils").get_devicons

	-- built per picker rather than cached, since entry_display resolves each
	-- width once and then holds it for the life of the displayer
	local displayer = require("telescope.pickers.entry_display").create({
		separator = " ",
		items = {
			{ width = 1 },
			{ width = LOCATION_WIDTH },
			{ remaining = true },
		},
	})

	return function(entry)
		local filename = entry.filename or vim.api.nvim_buf_get_name(entry.bufnr)
		local relative = vim.fn.fnamemodify(filename, ":.")
		local name = vim.fs.basename(relative)
		local text = vim.trim(entry.text or "")

		-- only the innermost directory: entry_display truncates from the right,
		-- which would keep exactly the leading segments every reference shares
		-- and drop the one that tells them apart
		local parent = vim.fs.dirname(relative)
		local directory = parent ~= "." and vim.fs.basename(parent) or ""

		return make_entry.set_default_entry_mt({
			value = entry,
			-- Match on the file name and the code only. gen_from_quickfix puts
			-- the whole path in the ordinal, where a long directory prefix
			-- shared by every reference matches most queries as a subsequence
			-- and nothing gets filtered out.
			ordinal = name .. " " .. text,
			display = function(item)
				local icon, icon_highlight = devicon(filename)

				-- "miner/worker.go:108" as one token, the way grep and compilers
				-- print a location. The column offset stays dropped: it is never
				-- navigated by and the preview lands the cursor on it anyway.
				-- entry.col still drives the jump, this is display only.
				local prefix = directory ~= "" and (directory .. "/") or ""
				local label = prefix .. name .. ":" .. item.lnum

				return displayer({
					{ icon, icon_highlight },
					-- a function highlighter returns ranges relative to its own
					-- column, which entry_display offsets into the row -- the
					-- only way to color the three parts inside a single cell
					{
						label,
						function()
							return {
								{ { 0, #prefix }, "TelescopeResultsComment" },
								{ { #prefix, #prefix + #name }, "TelescopeResultsIdentifier" },
								{ { #prefix + #name, #label }, "TelescopeResultsNumber" },
							}
						end,
					},
					text,
				})
			end,

			bufnr = entry.bufnr,
			filename = filename,
			lnum = entry.lnum,
			col = entry.col,
			text = entry.text,
			start = entry.start,
			finish = entry.finish,
		}, opts)
	end
end

-- <C-q> in the picker: whatever survived the fuzzy prompt (or the multi
-- selection) goes to the tree float, so searching happens where fuzzy matching
-- and <C-Space> refine live, and the grouped result lands where the tree and
-- paired preview do. Claimed here rather than through defaults.mappings because
-- attach_mappings is applied first, which also keeps the generic <C-q> from
-- opening this list under the " Quickfix " title.
local function send_to_float(prompt_bufnr)
	local actions = require("telescope.actions")

	-- no actions.close here: send_all_to_qf closes the picker itself, and a
	-- second close throws on the now-nil picker, killing everything after it.
	actions.smart_send_to_qflist(prompt_bufnr)

	vim.schedule(function()
		-- telescope titles the list with the query it was narrowed by
		local list = vim.fn.getqflist({ items = 0, title = 0 })
		M.open_items_float(list.items, list.title ~= "" and list.title or "References")
	end)
end

local function show_reference_picker(items)
	local opts = {
		entry_maker = reference_entry_maker({}),
		attach_mappings = function(_, map)
			map({ "i", "n" }, "<C-q>", send_to_float)
			return true
		end,
	}

	local conf = require("telescope.config").values
	require("telescope.pickers")
		.new(opts, {
			prompt_title = "LSP References",
			finder = require("telescope.finders").new_table({
				results = items,
				entry_maker = opts.entry_maker,
			}),
			previewer = conf.qflist_previewer(opts),
			sorter = conf.generic_sorter(opts),
			push_cursor_on_edit = true,
			push_tagstack_on_edit = true,
		})
		:find()
end

-- gr: request references from every attached server, discard locations outside
-- their workspace roots, then open Telescope. Fuzzy typing, <C-Space> refine,
-- and <C-q> continue to work; one surviving match still jumps directly.
function M.open_float()
	local bufnr = vim.api.nvim_get_current_buf()
	local winnr = vim.api.nvim_get_current_win()
	local current_path = normalize_path(vim.api.nvim_buf_get_name(bufnr))
	local current_line = vim.api.nvim_win_get_cursor(winnr)[1]
	local roots = workspace_roots(bufnr)

	local params = function(client)
		local value = vim.lsp.util.make_position_params(winnr, client.offset_encoding)
		value.context = { includeDeclaration = true }
		return value
	end

	vim.lsp.buf_request_all(bufnr, "textDocument/references", params, function(results_per_client)
		local items = {}

		for client_id, response in pairs(results_per_client) do
			if response.err then
				vim.notify(response.err.message or "Reference request failed", vim.log.levels.ERROR)
			elseif response.result then
				local client = vim.lsp.get_client_by_id(client_id)
				local encoding = client and client.offset_encoding or "utf-16"
				local locations = vim.tbl_filter(function(location)
					return location_is_in_workspace(location, roots)
				end, response.result)

				for _, item in ipairs(vim.lsp.util.locations_to_items(locations, encoding)) do
					local item_path = normalize_path(item.filename)
					if item_path ~= current_path or item.lnum ~= current_line then
						item._offset_encoding = encoding
						table.insert(items, item)
					end
				end
			end
		end

		if vim.tbl_isempty(items) then
			vim.notify("No workspace references found", vim.log.levels.INFO)
			return
		end

		if #items == 1 then
			vim.lsp.util.show_document(items[1].user_data, items[1]._offset_encoding, { reuse_win = false })
			return
		end

		show_reference_picker(items)
	end)
end

function M.open_items_float(items, title, context)
	if not items or vim.tbl_isempty(items) then
		vim.notify("No references found", vim.log.levels.INFO)
		return false
	end

	vim.fn.setqflist({}, " ", {
		title = title or "References",
		items = items,
		context = context,
	})

	trouble_float.focus_first_item(trouble_float.get(true).open(QFLIST_MODE))
	return true
end

return M
