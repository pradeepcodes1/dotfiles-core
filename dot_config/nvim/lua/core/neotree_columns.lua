-- cache expensive filesystem and Git metadata so rich columns never block Neo-tree rendering.
local git = require("neo-tree.git")
local highlights = require("neo-tree.ui.highlights")
local manager = require("neo-tree.sources.manager")
local utils = require("neo-tree.utils")
local uv = vim.uv or vim.loop

local M = {}

local caches = {
	git_context = {},
	git_age = {},
	smart_size = {},
	owner_group = {},
}

local inflight = {
	git_age = {},
	smart_size = {},
	owner_group = {},
}

local generations = {
	git_context = 0,
	git_age = 0,
	smart_size = 0,
	owner_group = 0,
}

local function clear(tbl)
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function reset(kind)
	generations[kind] = generations[kind] + 1
	clear(caches[kind])
	clear(inflight[kind] or {})
end

local function trim(text)
	local value = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return value
end

local function truncate(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end

	return vim.fn.strcharpart(text, 0, width)
end

local function format_field(text, config)
	local width = config.width or 8

	return {
		text = vim.fn.printf("%" .. width .. "s  ", truncate(text or "", width)),
		highlight = config.highlight or highlights.FILE_STATS,
	}
end

local function schedule_redraw()
	vim.schedule(function()
		pcall(manager.redraw, "filesystem")
	end)
end

local function format_relative_age(seconds)
	local diff = math.max(os.time() - seconds, 0)

	if diff < 60 then
		return "now"
	elseif diff < 3600 then
		return string.format("%dm", math.max(math.floor(diff / 60), 1))
	elseif diff < 86400 then
		return string.format("%dh", math.max(math.floor(diff / 3600), 1))
	elseif diff < 604800 then
		return string.format("%dd", math.max(math.floor(diff / 86400), 1))
	elseif diff < 2592000 then
		return string.format("%dw", math.max(math.floor(diff / 604800), 1))
	elseif diff < 31536000 then
		return string.format("%dmo", math.max(math.floor(diff / 2592000), 1))
	end

	return string.format("%dy", math.max(math.floor(diff / 31536000), 1))
end

local function normalize_path(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	return vim.fs.normalize(path)
end

local function stat_for(path)
	if not path then
		return nil
	end

	return uv.fs_stat(path)
end

local function git_lookup_path(path, stat)
	if stat and stat.type ~= "directory" then
		return normalize_path(vim.fs.dirname(path))
	end

	return path
end

local function git_worktree_for(path)
	path = normalize_path(path)
	if not path then
		return nil, nil
	end

	local stat = stat_for(path)
	local lookup_path = git_lookup_path(path, stat)
	local cached = caches.git_context[lookup_path]
	if cached ~= nil then
		return cached or nil, stat
	end

	local worktree_root = select(1, git.find_existing_worktree(path))
	if not worktree_root then
		worktree_root = select(1, git.find_worktree_info(lookup_path))
	end

	worktree_root = normalize_path(worktree_root)
	caches.git_context[lookup_path] = worktree_root or false

	return worktree_root, stat
end

local function relative_to(root, path)
	if path == root then
		return "."
	end

	if vim.startswith(path, root .. "/") then
		return path:sub(#root + 2)
	end

	return path
end

local function run_async(kind, key, command, on_exit)
	if inflight[kind][key] then
		return
	end

	local generation = generations[kind]
	inflight[kind][key] = true

	vim.system(command, { text = true }, function(result)
		vim.schedule(function()
			if generations[kind] ~= generation then
				return
			end

			inflight[kind][key] = nil
			on_exit(result)
			schedule_redraw()
		end)
	end)
end

local function load_git_age(path, worktree_root)
	run_async("git_age", path, {
		"git",
		"-C",
		worktree_root,
		"log",
		"-1",
		"--format=%ct",
		"--",
		relative_to(worktree_root, path),
	}, function(result)
		local seconds = tonumber(trim(result.stdout))
		if seconds then
			caches.git_age[path] = format_relative_age(seconds)
			return
		end

		local stderr = trim(result.stderr)
		if result.code == 0 or stderr:match("does not have any commits yet") then
			caches.git_age[path] = "new"
			return
		end

		caches.git_age[path] = "-"
	end)
end

local function load_smart_size(path)
	run_async("smart_size", path, { "du", "-sk", path }, function(result)
		local size_kb = tonumber(trim(result.stdout):match("^(%d+)"))
		if result.code == 0 and size_kb then
			caches.smart_size[path] = utils.human_size(size_kb * 1024)
			return
		end

		caches.smart_size[path] = "-"
	end)
end

local function load_owner_group(path)
	run_async("owner_group", path, { "stat", "-f", "%Su:%Sg", path }, function(result)
		local value = trim(result.stdout)
		if result.code == 0 and value ~= "" then
			caches.owner_group[path] = value
			return
		end

		caches.owner_group[path] = "-"
	end)
end

local function permission_triplet(value)
	local chars = {
		value >= 4 and "r" or "-",
		value % 4 >= 2 and "w" or "-",
		value % 2 == 1 and "x" or "-",
	}

	return table.concat(chars)
end

local function permission_prefix(stat)
	local prefixes = {
		block = "b",
		char = "c",
		directory = "d",
		fifo = "p",
		file = "-",
		link = "l",
		socket = "s",
	}

	return prefixes[stat.type] or "?"
end

local function format_permissions(stat)
	if not stat then
		return "-"
	end

	local perms = stat.mode % 512
	local user = math.floor(perms / 64)
	local group = math.floor(perms / 8) % 8
	local other = perms % 8

	return permission_prefix(stat) .. permission_triplet(user) .. permission_triplet(group) .. permission_triplet(other)
end

local function should_skip(node)
	return not node or node.type == "message" or not node.path
end

function M.invalidate_all()
	reset("git_context")
	reset("git_age")
	reset("smart_size")
	reset("owner_group")
end

function M.invalidate_git_age()
	reset("git_age")
end

function M.before_render(state)
	if state._smart_meta_root ~= state.path then
		state._smart_meta_root = state.path
		M.invalidate_all()
	end
end

function M.refresh(state)
	M.invalidate_all()
	require("neo-tree.sources.filesystem.commands").refresh(state)
end

function M.handle_fs_change()
	M.invalidate_all()
end

function M.git_age(config, node, _)
	if should_skip(node) then
		return {}
	end

	local worktree_root = git_worktree_for(node.path)
	if not worktree_root then
		return {}
	end

	if node.type == "directory" then
		return format_field("", config)
	end

	local cached = caches.git_age[node.path]
	if cached then
		return format_field(cached, config)
	end

	load_git_age(node.path, worktree_root)
	return format_field(config.loading_text or "…", config)
end

function M.smart_size(config, node, _)
	if should_skip(node) then
		return {}
	end

	local worktree_root, stat = git_worktree_for(node.path)
	if not worktree_root then
		return {}
	end

	if node.type == "directory" then
		local cached = caches.smart_size[node.path]
		if cached then
			return format_field(cached, config)
		end

		load_smart_size(node.path)
		return format_field(config.loading_text or "…", config)
	end

	if stat and stat.size then
		local ok, human = pcall(utils.human_size, stat.size)
		if ok then
			return format_field(human, config)
		end
	end

	return format_field("-", config)
end

function M.last_modified(config, node, _)
	if should_skip(node) then
		return {}
	end

	local _, stat = git_worktree_for(node.path)

	local seconds = stat and stat.mtime and stat.mtime.sec or nil
	return format_field(seconds and format_relative_age(seconds) or "-", config)
end

function M.permissions(config, node, _)
	if should_skip(node) then
		return {}
	end

	local _, stat = git_worktree_for(node.path)

	return format_field(format_permissions(stat), config)
end

function M.owner_group(config, node, _)
	if should_skip(node) then
		return {}
	end

	local cached = caches.owner_group[node.path]
	if cached then
		return format_field(cached, config)
	end

	load_owner_group(node.path)
	return format_field(config.loading_text or "…", config)
end

return M
