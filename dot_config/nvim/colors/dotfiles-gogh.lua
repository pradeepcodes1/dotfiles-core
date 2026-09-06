-- Neovim discovers colorschemes under colors/. Keep the implementation with
-- the rest of the runtime theme modules, and reload it on every :colorscheme.
package.loaded["theme.colorscheme"] = nil
require("theme.colorscheme")
