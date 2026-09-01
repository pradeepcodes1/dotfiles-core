-- search references in Telescope, then hand the survivors to the Trouble tree float.
local M = {}

local QFLIST_MODE = "references_qflist_float"
local trouble_float = require("core.trouble_float")

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

-- gr: the Telescope picker. Fuzzy typing, <C-Space> refine, and <C-q> to hand
-- whatever survived to the list float. Telescope jumps straight to a lone
-- reference itself, so a single match still lands on the location.
function M.open_float()
	require("telescope.builtin").lsp_references({
		include_declaration = true,
		include_current_line = false,

		-- the entry maker does its own trimming and path splitting, so
		-- trim_text and path_display would no longer be read here
		entry_maker = reference_entry_maker({}),
		attach_mappings = function(_, map)
			map({ "i", "n" }, "<C-q>", send_to_float)
			return true
		end,
	})
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
