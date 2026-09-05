# push the active palette into already-running Neovim/Neovide instances.
# Neovim theme integration

# Only a deliberate switch needs broadcasting. Every shell startup runs the
# renderers too (`_apply_theme_for init`), and an instance that is already
# running either got the last broadcast or read the persisted state when it
# started -- so an init pass would only fan a headless nvim out per instance
# to tell each of them what it already knows.
[[ "${_DOTFILES_THEME_APPLY_REASON:-init}" == "command" ]] || return

# Neovim names its server socket "<stdpath('run')>/nvim.<pid>.0", and that run
# directory is not the same shape on both platforms. With $XDG_RUNTIME_DIR set
# it *is* the run directory, so the sockets sit directly inside it. With it
# unset -- macOS, where nothing sets it and the old /run/user/$(id -u) fallback
# does not exist -- Neovim uses its own per-process temp dir instead, which is
# one level deeper: $TMPDIR/nvim.$USER/<random>/nvim.<pid>.0. Globbing only the
# flat form found nothing on macOS, so a `theme` switch left every running
# Neovim and Neovide on the old palette until it was restarted.
#
# $TMPDIR itself is per-launcher on macOS (a shell gets the per-user
# /var/folders/... one, a minimal environment falls back to /tmp), so both are
# searched: the broadcasting shell and a LaunchServices-started Neovide need
# not agree on it.
local -a _nvim_socks
local _nvim_dir _nvim_sock
local _nvim_user="${USER:-$(id -un)}"

[[ -n "$XDG_RUNTIME_DIR" ]] && _nvim_socks+=( "$XDG_RUNTIME_DIR"/nvim.*.0(N=) )

for _nvim_dir in "${TMPDIR:-/tmp}" /tmp; do
  [[ -n "$_nvim_dir" ]] || continue
  _nvim_socks+=( "${_nvim_dir%/}/nvim.$_nvim_user"/*/nvim.*.0(N=) )
done

# A crashed instance leaves its socket behind; connecting to one fails fast
# with "connection refused" rather than hanging, so stale entries cost nothing.
for _nvim_sock in "${(u)_nvim_socks[@]}"; do
  nvim --headless --server "$_nvim_sock" --remote-expr \
    'luaeval("pcall(vim.cmd, \"DotfilesThemeReload\")")' >/dev/null 2>&1
done
