-- tag the shared LSP client log with the writing process, at a usable level.

local log = vim.lsp.log

-- Every Neovim instance appends to the one ~/.local/state/nvim/lsp.log, so a
-- line on its own does not say which editor produced it. Resolve the pid once
-- here: entries are written from libuv callbacks, where vim.fn.* raises E5560
-- (vimL function must not be called in a lua loop callback). vim.uv is safe.
local pid = vim.uv.os_getpid()

local date_format = "%F %H:%M:%S"

-- Nvim's default formatter is also where the level check happens (see
-- runtime/lua/vim/lsp/log.lua), so replacing it means reimplementing the gate:
-- without it set_level() stops having any effect and every level is written.
-- Returning nil drops the entry.
--
-- The default header's source:line comes from debug.getinfo(2) inside
-- log.lua's own closure, so it always resolves to log.lua itself and says
-- nothing about the caller. Dropped in favor of the pid.
local function format(level, ...)
	if log.levels[level] < log.get_level() then
		return nil
	end

	local parts = { string.format("[%s][%s][pid:%d]", level, os.date(date_format), pid) }
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		table.insert(parts, arg == nil and "nil" or vim.inspect(arg, { newline = " ", indent = "" }))
	end
	return table.concat(parts, "\t") .. "\n"
end

log.set_format_func(format)

-- WARN, the nvim default, hides "Starting RPC client" and client_exit — the
-- two lines worth having when a server fails to launch or dies mid-session.
-- DEBUG and TRACE write every rpc payload both ways; reach for those per
-- session with :lua vim.lsp.log.set_level("debug"), not as a default.
log.set_level("info")

-- Reading it back. Nvim ships no :LspLog any more -- lspconfig dropped it once
-- 0.11 owned LSP config -- and the file is a single append-only log shared by
-- every instance ever run, tens of megabytes deep, with 2000 consecutive lines
-- routinely spanning 35 pids. So :edit is the wrong tool twice over. :LspLog
-- shows this instance's entries, which is what the pid above exists for;
-- :LspLog! shows every instance's; both take an optional line count.
--
-- The window then follows the file, so a server that dies while you watch says
-- so without reopening anything.
local default_lines = 300

-- Append new entries as they are written. Follow from `offset`, the file size
-- as of the snapshot, rather than `tail -n 0`: spawning is asynchronous, so
-- anything logged between the snapshot and tail opening the file would fall
-- into the gap -- which is exactly the window where an LSP server you just
-- provoked writes. `-F` rather than -f because the log is one file every
-- instance shares and something may yet rotate it.
--
-- vim.system's stdout callback lands in a fast event context and arrives on
-- chunk boundaries, not line ones: hold the trailing partial line back until
-- its newline shows up, and touch the buffer only inside vim.schedule.
local function follow(buf, path, offset, marker)
	local pending = ""

	local proc = vim.system({ "tail", "-c", "+" .. (offset + 1), "-F", path }, {
		stdout = function(err, data)
			if err or not data then
				return
			end

			pending = pending .. data
			local fresh = {}
			for line in pending:gmatch("([^\n]*)\n") do
				if not marker or line:find(marker, 1, true) then
					table.insert(fresh, line)
				end
			end
			pending = pending:match("[^\n]*$") or ""
			if #fresh == 0 then
				return
			end

			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end

				-- Only chase the tail for a reader already sitting at the end; someone
				-- scrolled up is reading, and yanking them away would be rude.
				local wins = vim.fn.win_findbuf(buf)
				local last = vim.api.nvim_buf_line_count(buf)
				local chasing = {}
				for _, win in ipairs(wins) do
					chasing[win] = vim.api.nvim_win_get_cursor(win)[1] >= last
				end

				vim.bo[buf].modifiable = true
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, fresh)
				vim.bo[buf].modifiable = false

				local bottom = vim.api.nvim_buf_line_count(buf)
				for win, follow_it in pairs(chasing) do
					if follow_it and vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_set_cursor(win, { bottom, 0 })
					end
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			proc:kill(15)
		end,
	})
end

local function open(lines, all)
	local path = log.get_filename()
	local offset = vim.fn.getfsize(path)
	if vim.fn.filereadable(path) == 0 then
		vim.notify("No LSP log at " .. path, vim.log.levels.WARN)
		return
	end

	local entries
	if all then
		entries = vim.fn.systemlist({ "tail", "-n", tostring(lines), path })
	else
		-- Grep the whole file rather than tailing it first: this instance's lines
		-- can sit far back in a log the other instances are still appending to.
		entries = vim.fn.systemlist({ "grep", "-F", ("[pid:%d]"):format(pid), path })
		if #entries > lines then
			entries = vim.list_slice(entries, #entries - lines + 1)
		end
	end

	if #entries == 0 then
		vim.notify(
			all and "LSP log is empty" or ("No LSP log entries yet for this instance (pid %d)"):format(pid),
			vim.log.levels.INFO
		)
		return
	end

	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
	vim.api.nvim_buf_set_name(buf, ("lsp.log [%s]"):format(all and "all instances" or "pid:" .. pid))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false -- a scratch view has no business in the tabline
	vim.bo[buf].filetype = "log"
	vim.bo[buf].modifiable = false
	vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, desc = "Close LSP log" })
	vim.cmd("normal! G") -- newest entry last, so land on it

	follow(buf, path, offset, not all and ("[pid:%d]"):format(pid) or nil)
end

vim.api.nvim_create_user_command("LspLog", function(opts)
	open(tonumber(opts.args) or default_lines, opts.bang)
end, {
	bang = true,
	nargs = "?",
	desc = "LSP log for this instance (:LspLog! for all, optional line count)",
})
