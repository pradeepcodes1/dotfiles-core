-- Dashboard pieces: the project name in block letters, a date/branch line, a
-- line of commit stats, and your recent commits.
-- Built in Lua so the dashboard needs no figlet.
local M = {}

-- 3x5 pixel glyphs, drawn two pixel rows per line with half blocks, so each
-- letter costs 4 columns and 3 lines. Small enough that a repo name fits the
-- dashboard pane, where the 6-line NEOVIM banner would not.
local GLYPHS = {
	A = { ".#.", "#.#", "###", "#.#", "#.#" },
	B = { "##.", "#.#", "##.", "#.#", "##." },
	C = { ".##", "#..", "#..", "#..", ".##" },
	D = { "##.", "#.#", "#.#", "#.#", "##." },
	E = { "###", "#..", "##.", "#..", "###" },
	F = { "###", "#..", "##.", "#..", "#.." },
	G = { ".##", "#..", "#.#", "#.#", ".##" },
	H = { "#.#", "#.#", "###", "#.#", "#.#" },
	I = { "###", ".#.", ".#.", ".#.", "###" },
	J = { "..#", "..#", "..#", "#.#", ".#." },
	K = { "#.#", "#.#", "##.", "#.#", "#.#" },
	L = { "#..", "#..", "#..", "#..", "###" },
	M = { "#.#", "###", "###", "#.#", "#.#" },
	N = { "##.", "#.#", "#.#", "#.#", "#.#" },
	O = { ".#.", "#.#", "#.#", "#.#", ".#." },
	P = { "##.", "#.#", "##.", "#..", "#.." },
	Q = { ".#.", "#.#", "#.#", "##.", ".##" },
	R = { "##.", "#.#", "##.", "#.#", "#.#" },
	S = { ".##", "#..", ".#.", "..#", "##." },
	T = { "###", ".#.", ".#.", ".#.", ".#." },
	U = { "#.#", "#.#", "#.#", "#.#", "###" },
	V = { "#.#", "#.#", "#.#", "#.#", ".#." },
	W = { "#.#", "#.#", "###", "###", "#.#" },
	X = { "#.#", "#.#", ".#.", "#.#", "#.#" },
	Y = { "#.#", "#.#", ".#.", ".#.", ".#." },
	Z = { "###", "..#", ".#.", "#..", "###" },
	["0"] = { "###", "#.#", "#.#", "#.#", "###" },
	["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
	["2"] = { "##.", "..#", ".#.", "#..", "###" },
	["3"] = { "##.", "..#", ".#.", "..#", "##." },
	["4"] = { "#.#", "#.#", "###", "..#", "..#" },
	["5"] = { "###", "#..", "##.", "..#", "##." },
	["6"] = { ".##", "#..", "###", "#.#", "###" },
	["7"] = { "###", "..#", ".#.", ".#.", ".#." },
	["8"] = { "###", "#.#", "###", "#.#", "###" },
	["9"] = { "###", "#.#", "###", "..#", "##." },
	["-"] = { "...", "...", "###", "...", "..." },
	["_"] = { "...", "...", "...", "...", "###" },
	["."] = { "...", "...", "...", "...", ".#." },
	[" "] = { "...", "...", "...", "...", "..." },
	["?"] = { "##.", "..#", ".#.", "...", ".#." },
}

local HALF = { ["##"] = "█", ["#."] = "▀", [".#"] = "▄", [".."] = " " }

local function blend(fg, bg, alpha)
	local function channel(shift)
		local a, b = bit.band(bit.rshift(fg, shift), 0xff), bit.band(bit.rshift(bg, shift), 0xff)
		return bit.lshift(math.floor(a * alpha + b * (1 - alpha) + 0.5), shift)
	end
	return channel(16) + channel(8) + channel(0)
end

local function hex_fg(name)
	return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
end

-- Stops are neighbours on the colour wheel (teal -> green -> gold -> orange in
-- gruvbox-like themes): blending two far-apart hues, like teal straight to
-- pink, goes grey in the middle.
local GRADIENT_STOPS = { "Function", "Special", "Type", "Constant" }

-- Base colour of each gradient group, left to right, so the shimmer can
-- brighten a group and put it back. Empty when the theme lacks a stop.
local shimmer_groups = {}

-- One highlight per cell along the stops. Re-set on every render so a
-- theme switch is picked up.
local function gradient(count)
	local stops = {}
	for _, name in ipairs(GRADIENT_STOPS) do
		table.insert(stops, hex_fg(name))
	end
	local groups = {}
	shimmer_groups = {}
	for i = 1, count do
		local group = "DashboardHeaderGradient" .. i
		local hl = { link = "SnacksDashboardHeader" }
		if #stops == #GRADIENT_STOPS then
			local pos = (count > 1 and (i - 1) / (count - 1) or 0) * (#stops - 1)
			local seg = math.min(math.floor(pos), #stops - 2)
			hl = { fg = blend(stops[seg + 2], stops[seg + 1], pos - seg), bold = true }
			table.insert(shimmer_groups, { group = group, fg = hl.fg, shown = hl.fg })
		end
		vim.api.nvim_set_hl(0, group, hl)
		groups[i] = group
	end
	return groups
end

-- Shimmer: a soft bright band sweeps across the title, then rests. Set
-- vim.g.dashboard_header_shimmer = false to keep the title still.
local SHIMMER = {
	fps = 30,
	sweep = 1.2, -- seconds for the band to cross
	pause = 3.5, -- seconds of rest between sweeps
	width = 6, -- band half-width, in cells
	strength = 0.6, -- how far the band's peak blends toward white
}

local shimmer_timer

local function dashboard_visible()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
			return true
		end
	end
	return false
end

local function set_shown(entry, fg)
	if entry.shown ~= fg then
		entry.shown = fg
		vim.api.nvim_set_hl(0, entry.group, { fg = fg, bold = true })
		return true
	end
	return false
end

local function stop_shimmer()
	if shimmer_timer then
		shimmer_timer:stop()
		shimmer_timer:close()
		shimmer_timer = nil
	end
	-- Leave the title at its plain gradient rather than frozen mid-sweep.
	for _, entry in ipairs(shimmer_groups) do
		set_shown(entry, entry.fg)
	end
end

-- Runs only while a dashboard window is on screen; it stops itself once the
-- dashboard is closed or hidden, and the next render starts it again.
local function start_shimmer()
	if shimmer_timer or vim.g.dashboard_header_shimmer == false then
		return
	end
	local started = vim.uv.now()
	shimmer_timer = vim.uv.new_timer()
	shimmer_timer:start(
		0,
		math.floor(1000 / SHIMMER.fps),
		vim.schedule_wrap(function()
			if not shimmer_timer then
				return
			end
			if vim.g.dashboard_header_shimmer == false or #shimmer_groups == 0 or not dashboard_visible() then
				return stop_shimmer()
			end
			local t = ((vim.uv.now() - started) / 1000) % (SHIMMER.sweep + SHIMMER.pause)
			-- The band enters from off the left edge; during the pause it sits
			-- past the right edge, so nothing changes and nothing redraws.
			local center = -SHIMMER.width + (t / SHIMMER.sweep) * (#shimmer_groups + 2 * SHIMMER.width)
			local changed = false
			for i, entry in ipairs(shimmer_groups) do
				local d = math.abs(i - center) / SHIMMER.width
				-- Cosine falloff so the band has soft edges instead of a hard stripe.
				local k = d < 1 and (math.cos(d * math.pi) + 1) / 2 * SHIMMER.strength or 0
				changed = set_shown(entry, k > 0 and blend(0xffffff, entry.fg, k) or entry.fg) or changed
			end
			-- Highlight changes only reach the screen on the next redraw.
			if changed then
				vim.api.nvim__redraw({ flush = true })
			end
		end)
	)
end

--- Block letters as dashboard text chunks, one chunk per glyph column per
--- line so the gradient (and the shimmer band) moves smoothly across cells.
local function banner(text)
	text = text:upper()
	local hls = gradient(#text * 3)
	local chunks = {}
	for line = 1, 3 do
		local index = 0
		for char in text:gmatch(".") do
			index = index + 1
			local glyph = GLYPHS[char] or GLYPHS["?"]
			local top, bottom = glyph[line * 2 - 1], glyph[line * 2] or "..."
			for col = 1, 3 do
				local cell = HALF[top:sub(col, col) .. bottom:sub(col, col)]
				local prefix = (index == 1 and line > 1 and col == 1) and "\n" or ""
				-- The gap after each letter rides on its last column.
				local suffix = col == 3 and " " or ""
				table.insert(chunks, { prefix .. cell .. suffix, hl = hls[(index - 1) * 3 + col] })
			end
		end
	end
	return chunks
end

--- Long names as plain caps, still graded letter by letter.
local function plain(text)
	text = text:upper()
	local hls = gradient(#text)
	local chunks = {}
	for i = 1, #text do
		table.insert(chunks, { text:sub(i, i), hl = hls[i] })
	end
	return chunks
end

local function git(root, args)
	local result = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
	return result.code == 0 and vim.trim(result.stdout) or nil
end

--- The project the cwd belongs to: the cwd itself when it has a saved
--- session, else the marker or git root of the cwd. nil in places like ~ that
--- are not a project.
local function find_project_root()
	local cwd = vim.uv.cwd()
	local ok, root = pcall(function()
		-- Asks project-manager directly now that dashboard_session.lua is gone;
		-- a marker root with a session was the marker root anyway.
		return require("project-manager.session").find(cwd) and cwd or require("project-manager.root").find(cwd)
	end)
	root = ok and root or Snacks.git.get_root(cwd)
	-- The markers include Makefile etc., so a stray one in ~ must not make home a project.
	if root and vim.fs.normalize(root) == vim.fs.normalize("~") then
		return nil
	end
	return root
end

-- The home view's Continue entry asks several times per render; resolve the
-- root (and its git calls) once, then drop it when the tick ends so the next
-- render sees a changed cwd.
local render
function M.cwd_root()
	if not render then
		render = { root = find_project_root() }
		vim.schedule(function()
			render = nil
		end)
	end
	return render.root
end

-- The dashboard is about whichever project its view has open, never the cwd,
-- so the home view looks the same wherever nvim starts.
local function project_root()
	return require("dotfiles.ui.dashboard").root
end

function M.header()
	local root = project_root()
	-- Repo names longer than the pane fall back to plain text rather than wrap.
	local name = root and vim.fs.basename(root) or "nvim"
	local text = #name <= 14 and banner(name) or plain(name)
	-- Each render rebuilt the gradient groups, so (re)start the sweep over them.
	start_shimmer()

	-- Just the date and branch; the greeting and username were dropped as noise.
	local info = { os.date("%a %d %b · %H:%M") }
	local branch = root and git(root, { "branch", "--show-current" })
	if branch and branch ~= "" then
		table.insert(info, " " .. branch)
	end

	return {
		align = "center",
		padding = 2,
		text = vim.list_extend(text, { { "\n\n" .. table.concat(info, "  ·  "), hl = "SnacksDashboardDesc" } }),
	}
end

-- The dashboard re-renders on resize and on every return to it; reuse git
-- output for a minute instead of rerunning log for each render.
local git_cache = {}

local function cached_git(root, args)
	local key = root .. "\0" .. table.concat(args, "\0")
	local hit = git_cache[key]
	if hit and os.time() - hit.at < 60 then
		return hit.out
	end
	local out = git(root, args) or ""
	git_cache[key] = { at = os.time(), out = out }
	return out
end

-- Stats, commits and changed files are about your own work in the repo, not
-- every contributor's.
local function author_args(root, args)
	local email = cached_git(root, { "config", "user.email" })
	if email ~= "" then
		table.insert(args, "--author=" .. email)
	end
	return args
end

-- Outside a git repo these sections render nothing, which also hides their titles.
local function git_root()
	local root = project_root()
	return root and Snacks.git.get_root(root) and root or nil
end

--- One line of your commit stats in place of the old heatmap grid: this week's
--- count, the run of consecutive days ending today or yesterday, and the
--- age of the last commit.
function M.stats()
	local root = git_root()
	if not root then
		return {}
	end

	-- 90 days bounds the streak walk; a longer streak shows as "90+".
	local days = {}
	for day in
		cached_git(root, author_args(root, { "log", "--since=90.days", "--format=%ad", "--date=short" })):gmatch("%S+")
	do
		days[day] = (days[day] or 0) + 1
	end

	local day = 24 * 60 * 60
	local now = os.time()
	-- Monday-based week, like most calendars; os.date("%w") is 0 for Sunday.
	local since_monday = (tonumber(os.date("%w", now)) + 6) % 7
	local week = 0
	for i = 0, since_monday do
		week = week + (days[os.date("%Y-%m-%d", now - i * day)] or 0)
	end

	-- A streak still counts if today has no commit yet but yesterday did.
	local streak, i = 0, days[os.date("%Y-%m-%d", now)] and 0 or 1
	while i < 90 and days[os.date("%Y-%m-%d", now - i * day)] do
		streak, i = streak + 1, i + 1
	end

	local parts = { ("%d commit%s this week"):format(week, week == 1 and "" or "s") }
	if streak > 1 then
		table.insert(parts, ("%s-day streak"):format(streak >= 90 and "90+" or streak))
	end
	local last = cached_git(root, author_args(root, { "log", "-1", "--format=%cr" }))
	if last ~= "" then
		table.insert(parts, "last " .. last)
	end
	return { align = "center", padding = 1, text = { { table.concat(parts, "  ·  "), hl = "SnacksDashboardDesc" } } }
end

-- Long subjects would spill past the pane; cut them to the given display width.
local function truncate(s, width)
	if vim.fn.strdisplaywidth(s) <= width then
		return s
	end
	return vim.fn.strcharpart(s, 0, width - 1) .. "…"
end

--- Your last few commits as plain rows: short hash, subject, relative age.
function M.commits(limit)
	local root = git_root()
	if not root then
		return {}
	end
	local out = cached_git(root, author_args(root, { "log", "-n", tostring(limit or 5), "--format=%h%x09%s%x09%cr" }))
	local items = {}
	for line in out:gmatch("[^\n]+") do
		local hash, subject, age = line:match("^(%S+)\t(.-)\t(.*)$")
		if hash then
			-- "2 hours ago" -> "2 hours": the column already reads as a time.
			age = age:gsub(" ago$", "")
			table.insert(items, {
				-- Desc, File and Special all link to Special in Snacks, so use
				-- Key/Normal/Dir to keep hash, subject and age distinct.
				text = {
					{ hash .. " ", hl = "SnacksDashboardKey" },
					{ truncate(subject, 40) .. " ", hl = "SnacksDashboardNormal" },
					{ age, hl = "SnacksDashboardDir" },
				},
			})
		end
	end
	return items
end

--- `git status --short --branch` as plain rows. A terminal section would show
--- Neovim's "[Process exited 0]" line whenever its output isn't cached yet.
function M.status(limit)
	local root = git_root()
	if not root then
		return {}
	end
	local out = cached_git(root, { "status", "--short", "--branch", "--renames" })
	local items = {}
	for line in out:gmatch("[^\n]+") do
		if #items >= (limit or 5) then
			break
		end
		local branch = line:match("^## (.*)$")
		if branch then
			table.insert(items, { text = { { branch, hl = "SnacksDashboardKey" } } })
		else
			-- XY code, then the path; color the code like git's own short status.
			local code, path = line:match("^(..) (.*)$")
			if code then
				local hl = code == "??" and "SnacksDashboardDir" or code:sub(1, 1) ~= " " and "Added" or "Changed"
				table.insert(items, {
					text = { { code .. " ", hl = hl }, { truncate(path, 40), hl = "SnacksDashboardNormal" } },
				})
			end
		end
	end
	return items
end

--- Snacks' default file format with one change: files under the cwd show
--- relative to it. Absolute paths get squashed to ~/.l/s/c/d/... in the narrow
--- pane; directories (Projects) keep the ~ form so they stay recognizable.
function M.format_file(item, ctx)
	local fname = vim.fn.fnamemodify(item.file, item.icon == "directory" and ":~" or ":~:.")
	-- The project view leaves the cwd alone, so show its files relative to the project.
	local root = project_root()
	if root and item.icon ~= "directory" and vim.startswith(item.file, root .. "/") then
		fname = item.file:sub(#root + 2)
	end
	fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
	if #fname > ctx.width then
		local dir = vim.fn.fnamemodify(fname, ":h")
		local file = vim.fn.fnamemodify(fname, ":t")
		if dir and file then
			file = file:sub(-(ctx.width - #dir - 2))
			fname = dir .. "/…" .. file
		end
	end
	local dir, file = fname:match("^(.*)/(.+)$")
	return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } } or { { fname, hl = "file" } }
end

return M
