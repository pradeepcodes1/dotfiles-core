-- show quiet, delayed feedback for LSP navigation requests.
local M = {}

local DELAY_MS = 200
local FRAME_MS = 80
local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local LABELS = {
	["textDocument/definition"] = "Finding definition…",
	["textDocument/references"] = "Finding references…",
	["workspace/symbol"] = "Finding symbol…",
}

local requests = {}
local timer
local notifier
local notification
local frame = 0
local generation = 0
local sequence = 0

local function request_key(client_id, request_id)
	return string.format("%d:%d", client_id, request_id)
end

local function symbol_under_cursor(bufnr)
	if bufnr ~= vim.api.nvim_get_current_buf() then
		return nil
	end

	local symbol = vim.fn.expand("<cword>")
	return symbol ~= "" and symbol or nil
end

local function current_label()
	local latest
	local clients = {}
	for _, request in pairs(requests) do
		clients[request.client] = true
		if not latest or request.sequence > latest.sequence then
			latest = request
		end
	end

	if not latest then
		return "Finding LSP results…"
	end

	local label = LABELS[latest.method]
	if latest.symbol then
		label = string.format("%s for “%s”", label:sub(1, -4), latest.symbol)
	end

	local client_names = vim.tbl_keys(clients)
	table.sort(client_names)
	local server = #client_names == 1 and client_names[1] or string.format("%d servers", #client_names)
	return string.format("%s · %s", label, server)
end

local function get_notifier()
	if notifier then
		return notifier
	end

	local ok, notify = pcall(require, "notify")
	if not ok then
		return nil
	end

	-- Keep navigation feedback separate from regular notifications so it can
	-- live at the bottom-right and be dismissed without touching other notices.
	notifier = notify.instance({
		background_colour = "#000000",
		minimum_width = 10,
		render = "minimal",
		stages = "static",
		timeout = false,
		top_down = false,
	})
	return notifier
end

local function render()
	if vim.tbl_isempty(requests) then
		return
	end

	local notify = get_notifier()
	if not notify then
		return
	end

	frame = (frame % #SPINNER) + 1
	local opts = {
		hide_from_history = true,
		timeout = false,
		title = "LSP",
	}
	if notification then
		opts.replace = notification
	end
	-- The minimal renderer intentionally omits notification icons, so the
	-- spinner belongs in the message where every frontend renders it.
	notification = notify(string.format("%s %s", SPINNER[frame], current_label()), vim.log.levels.INFO, opts)
end

local function stop()
	generation = generation + 1
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end

	if notifier and notification then
		notifier.dismiss({ pending = true, silent = true })
	end
	notification = nil
	frame = 0
end

local function start()
	if timer then
		return
	end

	generation = generation + 1
	local this_generation = generation
	timer = vim.uv.new_timer()
	timer:start(
		DELAY_MS,
		FRAME_MS,
		vim.schedule_wrap(function()
			if this_generation == generation then
				render()
			end
		end)
	)
end

function M.setup()
	local group = vim.api.nvim_create_augroup("lsp_navigation_progress", { clear = true })
	vim.api.nvim_create_autocmd("LspRequest", {
		group = group,
		callback = function(ev)
			local request = ev.data.request
			if not request or not LABELS[request.method] then
				return
			end

			local key = request_key(ev.data.client_id, ev.data.request_id)
			if request.type == "pending" then
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				sequence = sequence + 1
				requests[key] = {
					client = client and client.name or "LSP",
					method = request.method,
					sequence = sequence,
					symbol = symbol_under_cursor(ev.buf),
				}
				start()
			elseif request.type == "complete" or request.type == "cancel" then
				requests[key] = nil
				if vim.tbl_isempty(requests) then
					stop()
				end
			end
		end,
		desc = "Show delayed feedback for LSP navigation requests",
	})
end

return M
