# Keep every public diagram command while sharing rendering and cleanup paths.
_DIAGRAM_MMDC_WIDTH=1600
_DIAGRAM_MMDC_SCALE=2
: "${_DIAGRAM_MMDC_BG:=white}"
: "${_DIAGRAM_MMDC_THEME:=}"

_diagram_require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error_log "diagram" "$cmd not found in PATH"
      return 1
    fi
  done
}

_diagram_temp() {
  local base
  base="$(mktemp "${TMPDIR:-/tmp}/diagram-XXXXXX")" || return 1
  command mv "$base" "${base}.$1" || {
    command rm -f "$base"
    return 1
  }
  print -r -- "${base}.$1"
}

_diagram_cleanup() {
  local tmp_path
  for tmp_path in "$@"; do
    [[ -z "$tmp_path" ]] || command rm -f -- "$tmp_path"
  done
}

_diagram_render() {
  local input="$1" output="$2"
  local -a theme_args=()
  _diagram_require mmdc || return 1
  [[ -n "${_DIAGRAM_MMDC_THEME:-}" ]] && theme_args=(-t "$_DIAGRAM_MMDC_THEME")
  mmdc -i "$input" -o "$output" --backgroundColor "$_DIAGRAM_MMDC_BG" \
    -w "$_DIAGRAM_MMDC_WIDTH" -s "$_DIAGRAM_MMDC_SCALE" "${theme_args[@]}"
}

# Resolve supported inputs once so view, show, and copy share the same conversion rules.
_diagram_image() {
  local input="$1"
  _DIAGRAM_IMAGE=""
  _DIAGRAM_TEMP=""
  case "$input" in
    *.mmd)
      _DIAGRAM_TEMP="$(_diagram_temp png)" || return 1
      _diagram_render "$input" "$_DIAGRAM_TEMP" || {
        _diagram_cleanup "$_DIAGRAM_TEMP"
        return 1
      }
      _DIAGRAM_IMAGE="$_DIAGRAM_TEMP"
      ;;
    *.png|*.jpg|*.jpeg|*.svg|*.gif|*.webp) _DIAGRAM_IMAGE="$input" ;;
    *)
      error_log "diagram" "Unsupported file type: $input"
      return 1
      ;;
  esac
}

_diagram_open_excalidraw() {
  local input="$1" opener
  if command -v open >/dev/null 2>&1; then
    opener=open
  elif command -v xdg-open >/dev/null 2>&1; then
    opener=xdg-open
  else
    error_log "diagram" "No desktop opener found (install open or xdg-open)"
    return 1
  fi

  command "$opener" "$input" 2>/dev/null || {
    command "$opener" "https://excalidraw.com" || return 1
    info_log "diagram" "Drag $input into excalidraw.com to open"
    return
  }
  info_log "diagram" "Opened $input"
}

_diagram_copy_image() {
  local input="$1" mime
  case "$input" in
    *.png) mime=image/png ;;
    *.jpg|*.jpeg) mime=image/jpeg ;;
    *.gif) mime=image/gif ;;
    *.webp) mime=image/webp ;;
    *)
      error_log "diagram" "Unsupported clipboard image type: $input"
      return 1
      ;;
  esac

  if command -v osascript >/dev/null 2>&1; then
    command osascript - "$input" <<'APPLESCRIPT'
on run argv
  set the clipboard to (read POSIX file (item 1 of argv) as «class PNGf»)
end run
APPLESCRIPT
  elif command -v wl-copy >/dev/null 2>&1; then
    command wl-copy --type "$mime" < "$input"
  elif command -v xclip >/dev/null 2>&1; then
    command xclip -selection clipboard -target "$mime" -in < "$input"
  else
    error_log "diagram" "No image clipboard tool found (install wl-copy or xclip)"
    return 1
  fi
}

diagram() {
  local subcmd="${1:-help}"
  shift 2>/dev/null

  case "$subcmd" in
    render|svg)
      local input="${1:-}" extension=png output
      [[ "$subcmd" == svg ]] && extension=svg
      [[ -n "$input" ]] || {
        error_log "diagram" "Usage: diagram $subcmd <file.mmd> [output.$extension]"
        return 1
      }
      output="${2:-${input:r}.$extension}"
      info_log "diagram" "Rendering $input → $output"
      _diagram_render "$input" "$output"
      ;;

    view|show)
      local input="${1:-}" exit_status
      [[ -n "$input" ]] || {
        error_log "diagram" "Usage: diagram $subcmd <file>"
        return 1
      }
      [[ "$input" != *.excalidraw ]] || {
        _diagram_open_excalidraw "$input"
        return
      }
      _diagram_require timg || return 1
      _diagram_image "$input" || return 1

      if [[ "$subcmd" == view ]]; then
        timg --center -- "$_DIAGRAM_IMAGE"
        exit_status=$?
        _diagram_cleanup "$_DIAGRAM_TEMP"
        return $exit_status
      fi
      [[ -n "$TMUX" ]] || {
        _diagram_cleanup "$_DIAGRAM_TEMP"
        error_log "diagram" "show requires tmux"
        return 1
      }
      tmux new-window -n diagram bash -c \
        'trap '\''[[ -z "$2" ]] || rm -f -- "$2"'\'' EXIT; TIMG_PIXELATION=kitty timg --center -- "$1"; status=$?; read -rsn1; exit "$status"' \
        _ "$_DIAGRAM_IMAGE" "$_DIAGRAM_TEMP"
      exit_status=$?
      (( exit_status == 0 )) || _diagram_cleanup "$_DIAGRAM_TEMP"
      return $exit_status
      ;;

    pipe)
      local source image exit_status=0
      _diagram_require mmdc timg || return 1
      source="$(_diagram_temp mmd)" || return 1
      image="$(_diagram_temp png)" || {
        _diagram_cleanup "$source"
        return 1
      }
      command cat > "$source" || exit_status=$?
      (( exit_status != 0 )) || _diagram_render "$source" "$image" || exit_status=$?
      (( exit_status != 0 )) || timg --center -- "$image" || exit_status=$?
      _diagram_cleanup "$source" "$image"
      return $exit_status
      ;;

    copy)
      local input="${1:-}" copy_file copy_temp="" exit_status
      [[ -n "$input" ]] || {
        error_log "diagram" "Usage: diagram copy <file>"
        return 1
      }
      [[ "$input" != *.excalidraw ]] || {
        _diagram_open_excalidraw "$input"
        return
      }
      _diagram_image "$input" || return 1
      copy_file="$_DIAGRAM_IMAGE"
      if [[ "$copy_file" == *.svg ]]; then
        _diagram_require magick || {
          _diagram_cleanup "$_DIAGRAM_TEMP"
          return 1
        }
        copy_temp="$(_diagram_temp png)" || {
          # A rendered Mermaid input may already own a temporary image at this point.
          _diagram_cleanup "$_DIAGRAM_TEMP"
          return 1
        }
        magick "$copy_file" "$copy_temp" || {
          _diagram_cleanup "$_DIAGRAM_TEMP" "$copy_temp"
          return 1
        }
        copy_file="$copy_temp"
      fi
      _diagram_copy_image "$copy_file"
      exit_status=$?
      _diagram_cleanup "$_DIAGRAM_TEMP" "$copy_temp"
      (( exit_status != 0 )) || info_log "diagram" "Copied to clipboard"
      return $exit_status
      ;;

    help|*)
      print -r -- "Usage: diagram <render|svg|view|show|pipe|copy> [file] [output]"
      ;;
  esac
}
