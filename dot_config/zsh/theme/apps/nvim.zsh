# push the active palette into already-running Neovim/Neovide instances.
# Neovim theme integration

local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
local sock

for sock in "$runtime_dir"/nvim.*.0(N); do
  nvim --headless --server "$sock" --remote-expr \
    'luaeval("pcall(vim.cmd, \"DotfilesThemeReload\")")' >/dev/null 2>&1
done
