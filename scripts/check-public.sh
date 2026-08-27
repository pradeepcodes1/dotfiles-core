#!/bin/sh
# Reject private feature names in source paths, contents, and rendered output.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
private_pattern='mull''vad|tail''scale|cp[.]zsh|cpp[.]zsh|cp''t|cpp''-env|personal''-mac'

if find "$repo_dir" -path "$repo_dir/.git" -prune -o -print \
  | sed "s#^$repo_dir/##" | rg -i "$private_pattern"; then
  echo "private name found in a public path" >&2
  exit 1
fi

if rg -l -i --hidden --glob '!.git/**' "$private_pattern" "$repo_dir"; then
  echo "private reference found in public content" >&2
  exit 1
fi

packages=$(mktemp)
trap 'rm -f "$packages"' EXIT HUP INT TERM
chezmoi --source="$repo_dir" execute-template \
  --override-data '{"chezmoi":{"os":"linux"}}' \
  <"$repo_dir/dot_config/pacman/packages.tmpl" >"$packages"

if rg -i "$private_pattern" "$packages"; then
  echo "private reference found in rendered public output" >&2
  exit 1
fi

duplicates=$(awk 'NF && $1 !~ /^#/' "$packages" | sort | uniq -d)
if [ -n "$duplicates" ]; then
  echo "duplicate public packages:" >&2
  echo "$duplicates" >&2
  exit 1
fi
