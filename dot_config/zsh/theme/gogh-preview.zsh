#!/usr/bin/env zsh

# preview catalog colors in-process so choosing a Gogh theme does not mutate config.
emulate -L zsh

catalog_file="$1"
index="$2"

[[ -f "$catalog_file" && "$index" == <-> ]] || exit 1
command -v jq &>/dev/null || exit 1

record=$(jq -er --argjson index "$index" '
  .[$index]
  | select(.variant == "dark" or .variant == "light")
  | [.name, .variant, .background, .foreground,
    .color_01, .color_02, .color_03, .color_04,
    .color_05, .color_06, .color_07, .color_08,
    .color_09, .color_10, .color_11, .color_12,
    .color_13, .color_14, .color_15, .color_16][]
' "$catalog_file") || exit 1

values=("${(@f)record}")
[[ ${#values} -eq 20 ]] || exit 1

for color in "${values[@]:2}"; do
  [[ "$color" =~ '^#[0-9A-Fa-f]{6}$' ]] || exit 1
done

truecolor_fg() {
  local color="${1#\#}"
  printf '\e[38;2;%d;%d;%dm' \
    "$((16#${color[1,2]}))" "$((16#${color[3,4]}))" "$((16#${color[5,6]}))"
}

truecolor_bg() {
  local color="${1#\#}"
  printf '\e[48;2;%d;%d;%dm' \
    "$((16#${color[1,2]}))" "$((16#${color[3,4]}))" "$((16#${color[5,6]}))"
}

swatch() {
  truecolor_bg "$1"
  printf '    '
  printf '\e[0m '
}

printf '\e[1m%s\e[0m  %s\n' "$values[1]" "$values[2]"
printf 'Gogh catalog · exact terminal palette\n\n'

truecolor_bg "$values[3]"
truecolor_fg "$values[4]"
printf '  background / foreground  '
printf '\e[0m  %s  %s\n\n' "$values[3]" "$values[4]"

printf 'normal  '
for color in "${values[@]:4:8}"; do
  swatch "$color"
done
printf '\n        blk  red  grn  ylw  blu  mag  cyn  wht\n\n'

printf 'bright  '
for color in "${values[@]:12:8}"; do
  swatch "$color"
done
printf '\n        blk  red  grn  ylw  blu  mag  cyn  wht\n\n'

truecolor_fg "$values[7]"
printf '~/code/project '
truecolor_fg "$values[8]"
printf 'main '
truecolor_fg "$values[6]"
printf '+2 '
truecolor_fg "$values[5]"
printf '!1\n'
truecolor_fg "$values[9]"
printf '❯ '
truecolor_fg "$values[4]"
printf 'git status\n'
printf '\e[0m'
