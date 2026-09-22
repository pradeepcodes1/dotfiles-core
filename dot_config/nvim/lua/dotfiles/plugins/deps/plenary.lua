-- Lua helper library. Nothing here calls it directly: its consumers list it
-- under `dependencies`, and lazy.nvim loads it on the first `require` of one of
-- its modules either way. This spec exists only to pin one copy of it.
return { "nvim-lua/plenary.nvim", lazy = true }
