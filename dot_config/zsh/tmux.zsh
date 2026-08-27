#!/bin/zsh
# keep tmux opt-in while making session selection and cleanup convenient.
#
# tmux session picker. No longer runs at shell startup — kitty is the primary
# multiplexer now, so tmux is opt-in. Invoke it with `tmux-picker`, or from
# kitty with cmd+shift+t (see dot_config/kitty/kitty.conf.tmpl).

if command -v tmux &>/dev/null; then

  # Find the smallest available session number.
  _find_next_session_num() {
    local next_num=1
    local existing_nums=($(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -oE '^[0-9]+' | sort -n -u))

    # Find first gap in numbering
    for num in "${existing_nums[@]}"; do
      if [[ $num -eq $next_num ]]; then
        ((next_num++))
      elif [[ $num -gt $next_num ]]; then
        break
      fi
    done

    echo "$next_num"
  }

  _tmux_picker_rows() {
    tmux list-sessions -F "#{session_last_attached} #{session_name}: #{session_windows} windows (#{session_attached} attached)" 2>/dev/null | sort -rn | cut -d' ' -f2-
  }

  # Attach when the name is already taken instead of failing with tmux's
  # "duplicate session" error, matching what Shift+ROpt+c does in-tmux.
  _tmux_new_session() {
    local name="${1:?session name required}"
    if tmux has-session -t "=$name" 2>/dev/null; then
      tmux attach-session -t "=$name"
    else
      tmux new-session -s "$name"
    fi
  }

  # Ask for a session name, leaving it in REPLY. Returns nonzero when the
  # prompt is cancelled (^D) so the caller can drop back to the picker.
  # A plain `read` is enough because the picker only ever runs outside tmux;
  # the in-tmux path needs tmux's own command-prompt instead.
  _tmux_session_name_prompt() {
    setopt localoptions extendedglob
    local fallback="${1:?fallback name required}" name

    clear
    print -r -- ""
    print -r -- "  new tmux session"
    print -r -- "  ↵ empty for '${fallback}'   ^D cancel"
    print -r -- ""
    print -n -- "  name: "
    read -r name || { REPLY=""; return 1; }

    name="${${name##[[:space:]]#}%%[[:space:]]#}"
    # "." and ":" are tmux's target separators: a session named "a.b:c" is
    # created happily and can then never be addressed again, not even with
    # the "=" exact-match prefix. Fold them rather than stranding a session.
    name="${name//[.:]/-}"
    REPLY="${name:-$fallback}"
  }

  # Garbage collect unattached sessions (keep threshold total max). Runs when
  # the picker opens rather than on every shell start, so plain kitty shells
  # never reap sessions behind your back.
  _tmux_gc_sessions() {
    local threshold=3
    local total=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')

    [[ $total -gt $threshold ]] || return 0

    local kill_count=$((total - threshold))
    # Get unattached sessions sorted oldest first
    while IFS=: read -r created name attached; do
      (( attached > 0 )) && continue
      tmux kill-session -t "$name" 2>/dev/null
      kill_count=$((kill_count - 1))
      [[ $kill_count -le 0 ]] && break
    done < <(tmux list-sessions -F "#{session_created}:#{session_name}:#{session_attached}" 2>/dev/null | sort -n)
  }

  # Interactive session picker. Returns when you pick nothing, so calling it
  # from an existing shell is safe; when kitty launches it as a one-shot
  # command, returning ends that shell and closes the tab.
  tmux-picker() {
    [[ -z "$TMUX" ]] || {
      print -u2 "tmux-picker: already inside tmux"
      return 1
    }

    _tmux_gc_sessions

    while true; do
      if ! command -v fzf &>/dev/null; then
        # Fallback if fzf is not available
        local next_num=$(_find_next_session_num)
        tmux attach-session 2>/dev/null || _tmux_new_session "$next_num"
        return 0
      fi

      # Clear screen to hide login message
      clear

      local sessions="$(_tmux_picker_rows)"
      local prompt="> "
      local header="n new   ESC exit"
      local expect_keys="n"

      if [[ -n "$sessions" ]]; then
        header="↵ attach   n new   d kill   x kill-all   ESC exit"
        expect_keys="n,x,d"
      fi

      local result=$(
        {
          [[ -n "$sessions" ]] && print -r -- "$sessions"
        } | fzf --height=100% --no-input --prompt="$prompt" \
          --reverse --border=rounded --margin=49%,5%,0,5% --padding=1 \
          --header="tmux"$'\n'"$header"$'\n' \
          --expect="$expect_keys"
      )

      local picker_key="${result%%$'\n'*}"
      local choice="${result#*$'\n'}"
      [[ "$choice" == "$result" ]] && choice=""

      case "$picker_key" in
        n)
          # Recalculate next available number right before prompting, so the
          # offered default reflects any session killed earlier in this loop.
          local next_num=$(_find_next_session_num)
          if _tmux_session_name_prompt "$next_num"; then
            _tmux_new_session "$REPLY"
          fi
          continue
          ;;
        x)
          tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r sess; do
            tmux kill-session -t "$sess" 2>/dev/null
          done
          continue
          ;;
      esac

      if [[ -z "$choice" ]]; then
        # Cancelled — hand control back to the caller.
        clear
        return 0
      fi

      # Extract session name (everything before the first colon)
      local session_name="${choice%%:*}"

      if [[ "$picker_key" == "d" ]]; then
        tmux kill-session -t "$session_name" 2>/dev/null
        continue
      fi

      tmux attach-session -t "$session_name"
      # After tmux exits, loop back to show the selector again
    done
  }

  # Store HOME in pane-specific option so status bar can read it
  if [[ -n "$TMUX" ]]; then
    tmux set-option -p @pane_home "$HOME"
  fi
fi
