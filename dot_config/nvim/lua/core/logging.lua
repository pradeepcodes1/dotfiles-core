-- send editor events to the same structured log as the shell and helpers.

local M = {}

local config = {
	log_dir = vim.fn.expand("$HOME/.local/state/dotfiles/logs"),
	log_file = "dotfiles.jsonl",
	console_level = "WARN", -- WARN/ERROR show via notify
	file_level = "DEBUG", -- Everything to file
	enabled = vim.env.DOTFILES_JSON_LOG == "1",
}

local levels = { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

local function build_json(level, component, message, extra)
	local entry = {
		ts = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
		level = level,
		component = component,
		msg = message,
		source = "nvim",
		pid = vim.fn.getpid(),
	}
	if extra then
		for k, v in pairs(extra) do
			entry[k] = v
		end
	end
	return vim.json.encode(entry)
end

local function write_log(json_entry)
	if not config.enabled then
		return
	end

	vim.fn.mkdir(config.log_dir, "p")
	local log_path = config.log_dir .. "/" .. config.log_file
	local file = io.open(log_path, "a")
	if file then
		file:write(json_entry .. "\n")
		file:close()
	end
end

local function should_console(level)
	return levels[level] >= levels[config.console_level]
end

local function should_file(level)
	return config.enabled and levels[level] >= levels[config.file_level]
end

function M.log(level, component, message, extra)
	level = level:upper()

	-- Write to file
	if should_file(level) then
		write_log(build_json(level, component, message, extra))
	end

	-- Show via notify for console levels
	if should_console(level) then
		local ok, notify = pcall(require, "notify")
		if ok then
			local notify_level = vim.log.levels[level] or vim.log.levels.INFO
			notify(message, notify_level, { title = component })
		end
	end
end

local function level_logger(level)
	return function(component, message, extra)
		M.log(level, component, message, extra)
	end
end

for level in pairs(levels) do
	M[level:lower()] = level_logger(level)
end

return M
