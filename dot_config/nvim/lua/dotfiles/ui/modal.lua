-- Hydra-style modes on which-key's loop, replacing hydra.nvim: one key enters,
-- single-key heads repeat until q or <Esc>, and which-key draws the hint from
-- the heads' descriptions instead of a hand-maintained hint string. Like the
-- old pink Hydras, other keys run as usual and the mode stays open.
local M = {}

--- `node` is an F-key no keyboard sends. which-key runs a node's own keymap
--- rather than opening it, so the entry key (<leader>h, <leader>w) cannot also
--- be the node the heads hang on. `heads` is called on every redraw, so it can
--- answer differently per buffer or tab.
function M.new(node, name, heads)
	local opts = { keys = node, loop = true }
	local registered = false
	return function()
		-- Registered on first use: keymaps/init.lua builds its modes before
		-- lazy.nvim has put which-key on the runtimepath.
		if not registered then
			registered = true
			require("which-key").add({
				node,
				group = name,
				expand = function()
					local list = {}
					for _, head in ipairs(heads()) do
						local action = head[2]
						list[#list + 1] = vim.tbl_extend("force", head, {
							[2] = function()
								-- Each loop pass counts toward which-key's 50-start recursion
								-- guard, which a held key (resizing with l) would trip.
								require("which-key.state").recursion = 0
								action()
							end,
						})
					end
					-- which-key's loop otherwise ends only on <Esc>; q left the Hydra too.
					list[#list + 1] = {
						"q",
						function()
							opts.loop = false
						end,
						desc = "exit",
					}
					return list
				end,
			})
		end
		opts.loop = true
		require("which-key").show(opts)
	end
end

return M
