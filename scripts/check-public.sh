#!/bin/sh
# Reject private feature names in source paths, contents, and rendered output.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# Names are split with '' so this pattern cannot match its own source file
# when the content scan below reaches scripts/.
private_pattern='mull''vad|tail''scale|cp[.]zsh|cpp[.]zsh|cp''t|cpp''-env|personal''-mac|riced''-linux'

if find "$repo_dir" -path "$repo_dir/.git" -prune -o -print \
  | sed "s#^$repo_dir/##" | rg -i "$private_pattern"; then
  echo "private name found in a public path" >&2
  exit 1
fi

if rg -l -i --hidden --glob '!.git/**' "$private_pattern" "$repo_dir"; then
  echo "private reference found in public content" >&2
  exit 1
fi

rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT HUP INT TERM

for manifest in dot_config/pacman/packages.tmpl dot_config/pacman/aur-packages.tmpl; do
  chezmoi --source="$repo_dir" execute-template \
    --override-data '{"chezmoi":{"os":"linux"}}' \
    <"$repo_dir/$manifest" >"$rendered"

  if rg -i "$private_pattern" "$rendered"; then
    echo "private reference found in rendered public output: $manifest" >&2
    exit 1
  fi

  duplicates=$(awk 'NF && $1 !~ /^#/' "$rendered" | sort | uniq -d)
  if [ -n "$duplicates" ]; then
    echo "duplicate public packages in $manifest:" >&2
    echo "$duplicates" >&2
    exit 1
  fi
done
