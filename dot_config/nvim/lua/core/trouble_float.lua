-- move focus onto the first result because Trouble floats initially select their container.
local M = {}

function M.get(load)
	if package.loaded.trouble or load then
		return require("trouble")
	end
end

-- A one-line fuzzy prompt anchored under the float, filtering the tree live as
-- you type, with the selection and preview following the way an fzf window
-- does. vim.fn.matchfuzzy is the matcher, so a query matches as a subsequence
-- and space-separated words are ANDed.
--
-- Refiltering is cheap even though View:filter triggers a full section refresh:
-- trouble caches LSP locations by buffer and cursor, and only clears that cache
-- on TextChanged in a `buftype == ""` buffer. The prompt is a scratch buffer,
-- so typing in it never invalidates the references behind the tree.
--
-- Trouble filters are item predicates, not list transformers: View:filter always
-- hands Filter.is a list, and a function inside one is dispatched per item. So
-- this matches an item at a time behind a text cache rather than ranking the
-- whole set at once -- the tree grouping is what orders results anyway.
local LIVE_ID = "fuzzy:live"
local prompts = setmetatable({}, { __mode = "k" })
local stacks = setmetatable({}, { __mode = "k" })

local function fuzzy_predicate(query)
	local cache = {}

	return function(item)
		local text = (item.filename or "") .. " " .. (item.text or "")
		local matched = cache[text]

		if matched == nil then
			matched = #vim.fn.matchfuzzy({ text }, query) > 0
			cache[text] = matched
		end

		return matched
	end
end

-- nvim_win_get_config reports row/col as a plain number on current Neovim, but
-- older versions wrap them in a { [false] = n } table.
local function coord(value)
	if type(value) == "table" then
		return value[false] or value[1] or 0
	end

	return value or 0
end

local function drop_filter(view, id)
	view:filter(nil, { id = id, del = true })
end

function M.clear_fuzzy(view)
	if not view or type(view.get_filter) ~= "function" then
		return
	end

	for _, id in ipairs(stacks[view] or {}) do
		if view:get_filter(id) then
			drop_filter(view, id)
		end
	end
	stacks[view] = nil

	if view:get_filter(LIVE_ID) then
		drop_filter(view, LIVE_ID)
	end
end

-- The trouble window is not current while the prompt has focus, so its own
-- CursorMoved-driven auto_preview never fires -- the preview has to be asked
-- for directly. Queued through View:wait rather than called inline, because
-- View:action defers onto the same promise: reading the position straight after
-- an action returns the item from *before* the move.
local function preview_current(view)
	view:wait(function()
		if not (view.win and view.win:valid()) then
			return
		end

		local at = view:at() or {}
		if at.item then
			view:preview(at.item)
		end
	end)
end

-- Put the cursor back on the first result and preview it, the way a picker
-- re-selects the top hit after every keystroke.
local function settle(view)
	vim.schedule(function()
		if not (view.win and view.win:valid()) then
			return
		end

		pcall(vim.api.nvim_win_set_cursor, view.win.win, { 1, 0 })

		if not (view:at() or {}).item then
			view:action("next")
		end

		preview_current(view)
	end)
end

local function apply_live(view, query)
	if query == "" then
		if view:get_filter(LIVE_ID) then
			drop_filter(view, LIVE_ID)
		end
	else
		view:filter(fuzzy_predicate(query), {
			id = LIVE_ID,
			template = "{hl:Comment}fuzzy: {query}{hl}",
			data = { query = query },
		})
	end

	settle(view)
end

-- "fuzzy over": freeze the current query as its own filter and start a fresh
-- one over what survived, so the applied queries stack in the header.
local function commit_live(view, buf)
	local query = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
	if query == "" then
		return
	end

	local stack = stacks[view] or {}
	local id = "fuzzy:" .. (#stack + 1) .. ":" .. query
	stack[#stack + 1] = id
	stacks[view] = stack

	view:filter(fuzzy_predicate(query), {
		id = id,
		template = "{hl:Comment}fuzzy: {query}{hl}",
		data = { query = query },
	})

	if view:get_filter(LIVE_ID) then
		drop_filter(view, LIVE_ID)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	settle(view)
end

local function close_prompt(view)
	local prompt = prompts[view]
	if not prompt then
		return
	end
	prompts[view] = nil

	pcall(vim.api.nvim_del_augroup_by_id, prompt.group)
	vim.cmd.stopinsert()

	if vim.api.nvim_win_is_valid(prompt.win) then
		vim.api.nvim_win_close(prompt.win, true)
	end

	if view.win and view.win:valid() then
		vim.api.nvim_set_current_win(view.win.win)
	end
end

--- Open the fuzzy prompt if it is not already up.
function M.open_fuzzy(view)
	if not view or not view.win or type(view.win.valid) ~= "function" or not view.win:valid() then
		return
	end

	if prompts[view] then
		return
	end

	local target = view.win.win
	local config = vim.api.nvim_win_get_config(target)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"

	-- directly beneath the float: its own bottom border, then the prompt's top
	local win = vim.api.nvim_open_win(buf, true, {
		relative = config.relative ~= "" and config.relative or "editor",
		row = coord(config.row) + config.height + 2,
		col = coord(config.col),
		width = config.width,
		height = 1,
		border = "rounded",
		title = " Fuzzy ",
		title_pos = "center",
		style = "minimal",
		zindex = (config.zindex or 50) + 1,
	})

	-- Keep nvim-cmp out of the prompt. On InsertEnter cmp wraps every key in
	-- its mapping table with its own buffer-local map, and <C-Space>, <CR>,
	-- <C-j> and <C-k> are all in it (core/cmp.lua) -- cmp.mapping.complete()
	-- never calls the fallback, so the prompt's own bindings were dead. cmp
	-- gates that whole pass on config.enabled(), which reads buffer config.
	pcall(function()
		require("cmp").setup.buffer({ enabled = false })
	end)

	local group = vim.api.nvim_create_augroup("TroubleFuzzyPrompt" .. buf, { clear = true })

	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		group = group,
		buffer = buf,
		callback = function()
			apply_live(view, vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""))
		end,
	})

	-- the tree closing under us has to take the prompt with it
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = tostring(target),
		callback = function()
			close_prompt(view)
		end,
	})

	local function map(lhs, fn)
		vim.keymap.set({ "i", "n" }, lhs, fn, { buffer = buf, nowait = true, silent = true })
	end

	local function step(action)
		return function()
			if not (view.win and view.win:valid()) then
				return
			end

			view:action(action)
			preview_current(view)
		end
	end

	map("<c-j>", step("next"))
	map("<down>", step("next"))
	map("<c-k>", step("prev"))
	map("<up>", step("prev"))

	map("<cr>", function()
		local at = view:at() or {}
		close_prompt(view)
		if at.item then
			view:action("jump_close")
		end
	end)

	-- leave the prompt but keep what it filtered, so j/k/<cr> work in the tree
	map("<esc>", function()
		close_prompt(view)
	end)

	map("<c-space>", function()
		commit_live(view, buf)
	end)

	map("<c-c>", function()
		M.clear_fuzzy(view)
		close_prompt(view)
	end)

	prompts[view] = { win = win, buf = buf, group = group }

	-- reopening on an active query should let you edit it, not retype it
	local live = view:get_filter(LIVE_ID)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { live and live.data and live.data.query or "" })
	vim.cmd.startinsert({ bang = true })

	-- the preview is live from the moment the prompt opens, not from the first
	-- time the selection moves
	preview_current(view)
end

--- Toggle the fuzzy prompt. Bound to <C-Space> inside the tree itself.
function M.fuzzy_filter(view)
	if view and prompts[view] then
		return close_prompt(view)
	end

	return M.open_fuzzy(view)
end

function M.focus_first_item(view)
	if not view or type(view.wait) ~= "function" then
		return view
	end

	-- a reopened float must not inherit the previous session's fuzzy stack
	M.clear_fuzzy(view)

	view:wait(function()
		if not view.win or type(view.win.valid) ~= "function" or not view.win:valid() then
			return
		end

		local loc = view:at() or {}
		if loc.item then
			return
		end

		view:action("next")
	end)

	return view
end

return M
