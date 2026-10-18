-- Neovim discovers colorschemes under colors/. Keep the implementation with
-- the rest of the runtime theme modules, and reload it on every :colorscheme.
-- The cache key must match the require path exactly; a stale key left the
-- cached module in place, so a live reload kept the old palette's highlights.
package.loaded["dotfiles.theme.colorscheme"] = nil
require("dotfiles.theme.colorscheme")
