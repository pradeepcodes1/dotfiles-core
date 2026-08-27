#!/usr/bin/env bash
# summarize the current repository, using one root for both tools.
# LESSUTFCHARDEF lets less pass Nerd Font private-use glyphs through.

root=$(git rev-parse --show-toplevel 2>/dev/null)

{
  if [[ -z "$root" ]]; then
    printf 'repo-stats: not inside a git repository (%s)\n' "$PWD"
  else
    onefetch --no-art --no-color-palette --nerd-fonts "$root"
    tokei "$root"
  fi
} 2>&1 | LESSUTFCHARDEF='E000-F8FF:p,F0000-FFFFD:p' less -RQ

[[ -n "$root" ]]
