#!/usr/bin/env bash
# open lazygit with the window titled "<repo> - lazygit" ("lazygit" outside a
# repo) so the narrow kitty tab shows which repo it is, like nvim's "<project> - vi".

root=$(git rev-parse --show-toplevel 2>/dev/null)
printf '\033]2;%s\007' "${root:+${root##*/} - }lazygit"
exec lazygit "$@"
