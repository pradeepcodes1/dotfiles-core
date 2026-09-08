-- smooth cursor motion while suppressing distracting trails during sidebar transitions.
return {
	"sphamba/smear-cursor.nvim",

	-- Neovide draws its own animated cursor, and smear-cursor is explicitly for
	-- text-only frontends. It also cannot place its smear correctly here:
	-- Neovide enables ext_multigrid, under which screenrow()/screencol() return
	-- window-local coordinates, and smear-cursor feeds those straight into a
	-- relative="editor" float. The smear therefore lands in whatever window
	-- occupies those global cells - with a vertical split, the wrong one.
	cond = not vim.g.neovide,
	opts = {
		-- Opening the sidebar crosses buffers twice; do not draw a cursor trail
		-- through the Symbols pane while that happens.
		smear_between_buffers = true,
		smear_between_neighbor_lines = true,
		scroll_buffer_space = true,

		-- A fast head with a slower tail approximates Neovide's short, fluid stretch.
		stiffness = 0.8,
		trailing_stiffness = 0.6,
		stiffness_insert_mode = 0.7,
		trailing_stiffness_insert_mode = 0.7,
		damping = 0.95,
		damping_insert_mode = 0.95,
		distance_stop_animating = 0.5,
		time_interval = 7,

		-- Bound long jumps so window navigation stays closer to Neovide's compact trail.
		max_length = 8,
	},
}
