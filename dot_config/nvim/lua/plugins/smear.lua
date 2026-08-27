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
		smear_between_buffers = false,

		-- Smoother cursor movement
		stiffness = 0.8, -- Higher = less lag, more responsive (0.6-1.0)
		trailing_stiffness = 0.9, -- How fast the trail follows
		stiffness_insert_mode = 0.8,
		trailing_stiffness_insert_mode = 0.8,
		damping = 0.95, -- Higher = less overshoot/bounce
		damping_insert_mode = 0.95,

		-- Distance from cursor before smear effect starts
		distance_stop_animating = 0.5,

		-- Cap how far the trail can stretch on big jumps (default 25)
		max_length = 8,
	},
}
