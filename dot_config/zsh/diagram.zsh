# render and preview diagrams without leaving the terminal workflow.
# Terminal diagramming: render and view Mermaid/Excalidraw/images
_DIAGRAM_MMDC_WIDTH=1600
_DIAGRAM_MMDC_SCALE=2

# Theme-aware defaults (overridden by theme/apps/diagram.zsh)
: "${_DIAGRAM_MMDC_BG:=white}"
: "${_DIAGRAM_MMDC_THEME:=}"

_diagram_mktemp() {
  local base tmp_path
  base="$(mktemp /tmp/diagram-XXXXXX)" || return 1
  tmp_path="${base}.$1"
  command mv "$base" "$tmp_path" || {
    command rm -f "$base"
    return 1
  }
  print -r -- "$tmp_path"
}

_diagram_cleanup() {
  local tmp_path
  for tmp_path in "$@"; do
    [[ -z "$tmp_path" ]] || command rm -f -- "$tmp_path"
  done
}

_diagram_open_path() {
  local target="$1"
  if (( $+commands[open] )); then
    command open "$target"
  elif (( $+commands[xdg-open] )); then
    command xdg-open "$target"
  else
    error_log "diagram" "No desktop opener found (install open or xdg-open)"
    return 1
  fi
}

_diagram_open_excalidraw() {
  local input="$1"
  _diagram_open_path "$input" 2>/dev/null || {
    _diagram_open_path "https://excalidraw.com" || return 1
    info_log "diagram" "Drag $input into excalidraw.com to open"
    return
  }
  info_log "diagram" "Opened $input"
}

_diagram_copy_image() {
  local input="$1" mime_type

  case "$input" in
    *.png) mime_type="image/png" ;;
    *.jpg|*.jpeg) mime_type="image/jpeg" ;;
    *.gif) mime_type="image/gif" ;;
    *.webp) mime_type="image/webp" ;;
    *)
      error_log "diagram" "Unsupported clipboard image type: $input"
      return 1
      ;;
  esac

  if (( $+commands[osascript] )); then
    command osascript - "$input" <<'APPLESCRIPT'
on run argv
  set image_file to POSIX file (item 1 of argv)
  set the clipboard to (read image_file as «class PNGf»)
end run
APPLESCRIPT
  elif (( $+commands[wl-copy] )); then
    command wl-copy --type "$mime_type" < "$input"
  elif (( $+commands[xclip] )); then
    command xclip -selection clipboard -target "$mime_type" -in < "$input"
  else
    error_log "diagram" "No image clipboard tool found (install wl-copy or xclip)"
    return 1
  fi
}

_diagram_mmdc() {
  local input="$1" output="$2"
  local -a theme_args=()
  [[ -n "${_DIAGRAM_MMDC_THEME:-}" ]] && theme_args=(-t "$_DIAGRAM_MMDC_THEME")
  mmdc -i "$input" -o "$output" --backgroundColor "$_DIAGRAM_MMDC_BG" \
    -w "$_DIAGRAM_MMDC_WIDTH" -s "$_DIAGRAM_MMDC_SCALE" "${theme_args[@]}"
}

# Resolve any supported input to a displayable image path. Sets _DIAGRAM_IMG and
# _DIAGRAM_TMP; callers must clean up the latter when it is non-empty.
_diagram_to_img() {
  local input="$1"
  _DIAGRAM_IMG=""
  _DIAGRAM_TMP=""
  case "$input" in
    *.mmd)
      _diagram_check mmdc || return 1
      _DIAGRAM_TMP="$(_diagram_mktemp png)" || return 1
      if ! _diagram_mmdc "$input" "$_DIAGRAM_TMP"; then
        _diagram_cleanup "$_DIAGRAM_TMP"
        _DIAGRAM_TMP=""
        return 1
      fi
      _DIAGRAM_IMG="$_DIAGRAM_TMP"
      ;;
    *.png|*.jpg|*.jpeg|*.svg|*.gif|*.webp)
      _DIAGRAM_IMG="$input"
      ;;
    *)
      error_log "diagram" "Unsupported file type: $input"
      return 1
      ;;
  esac
}

function diagram() {
  local subcmd="${1:-help}"
  shift 2>/dev/null

  case "$subcmd" in
    render|svg)
      local input="${1:-}" extension="png" output
      [[ "$subcmd" == "svg" ]] && extension="svg"
      if [[ -z "$input" ]]; then
        error_log "diagram" "Usage: diagram $subcmd <file.mmd> [output.$extension]"
        return 1
      fi
      _diagram_check mmdc || return 1
      output="${2:-${input:r}.$extension}"
      info_log "diagram" "Rendering $input → $output"
      _diagram_mmdc "$input" "$output"
      ;;

    view|show)
      local input="${1:-}"
      if [[ -z "$input" ]]; then
        error_log "diagram" "Usage: diagram $subcmd <file>"
        return 1
      fi
      if [[ "$input" == *.excalidraw ]]; then
        _diagram_open_excalidraw "$input"; return
      fi
      _diagram_check timg || return 1
      if [[ "$subcmd" == "show" && -z "$TMUX" ]]; then
        error_log "diagram" "show requires tmux"
        return 1
      fi
      _diagram_to_img "$input" || return 1
      local img="$_DIAGRAM_IMG"
      local tmp_cleanup="$_DIAGRAM_TMP"
      local exit_status

      if [[ "$subcmd" == "view" ]]; then
        timg --center -- "$img"
        exit_status=$?
        _diagram_cleanup "$tmp_cleanup"
        return "$exit_status"
      fi

      tmux new-window -n "diagram" bash -c \
        'cleanup_path=$2
         cleanup() { [[ -z "$cleanup_path" ]] || rm -f -- "$cleanup_path"; }
         trap cleanup EXIT
         TIMG_PIXELATION=kitty timg --center -- "$1"
         status=$?
         read -rsn1
         exit "$status"' _ "$img" "$tmp_cleanup"
      exit_status=$?
      (( exit_status == 0 )) || _diagram_cleanup "$tmp_cleanup"
      return "$exit_status"
      ;;

    pipe)
      _diagram_check mmdc timg || return 1
      local tmp_mmd tmp_png exit_status=0
      tmp_mmd="$(_diagram_mktemp mmd)" || return 1
      tmp_png="$(_diagram_mktemp png)" || {
        _diagram_cleanup "$tmp_mmd"
        return 1
      }
      command cat > "$tmp_mmd" || exit_status=$?
      if (( exit_status == 0 )); then
        _diagram_mmdc "$tmp_mmd" "$tmp_png" || exit_status=$?
      fi
      if (( exit_status == 0 )); then
        timg --center -- "$tmp_png" || exit_status=$?
      fi
      _diagram_cleanup "$tmp_mmd" "$tmp_png"
      return "$exit_status"
      ;;

    copy)
      local input="${1:-}"
      if [[ -z "$input" ]]; then
        error_log "diagram" "Usage: diagram copy <file>"
        return 1
      fi
      if [[ "$input" == *.excalidraw ]]; then
        _diagram_open_excalidraw "$input"; return
      fi
      _diagram_to_img "$input" || return 1
      local img="$_DIAGRAM_IMG"
      local tmp_render="$_DIAGRAM_TMP"
      local copy_file="$img"
      local tmp_copy=""
      local exit_status
      if [[ "$img" == *.svg ]]; then
        _diagram_check magick || {
          _diagram_cleanup "$tmp_render"
          return 1
        }
        tmp_copy="$(_diagram_mktemp png)" || {
          _diagram_cleanup "$tmp_render"
          return 1
        }
        copy_file="$tmp_copy"
        magick "$img" "$copy_file"
        exit_status=$?
        if (( exit_status != 0 )); then
          _diagram_cleanup "$tmp_render" "$tmp_copy"
          return "$exit_status"
        fi
      fi
      _diagram_copy_image "$copy_file"
      exit_status=$?
      _diagram_cleanup "$tmp_render" "$tmp_copy"
      (( exit_status == 0 )) || return "$exit_status"
      info_log "diagram" "Copied to clipboard"
      ;;

    help|*)
      echo "Usage: diagram <command> [args]"
      echo ""
      echo "Commands:"
      echo "  render <file.mmd> [output.png]  Render Mermaid to PNG"
      echo "  svg    <file.mmd> [output.svg]  Render Mermaid to SVG"
      echo "  view   <file>                   Render + display inline"
      echo "                                  (.mmd, .excalidraw, .png, .svg, ...)"
      echo "  show   <file>                   Fullscreen tmux popup (any key to close)"
      echo "  pipe                            Read Mermaid from stdin, render + display"
      echo "  copy   <file>                   Render + copy to the system clipboard"
      ;;
  esac
}

_diagram_check() {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null; then
      error_log "diagram" "$cmd not found in PATH"
      return 1
    fi
  done
}
