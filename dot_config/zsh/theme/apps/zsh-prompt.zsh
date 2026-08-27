# preserve compact command history while showing status and duration at the right time.
# Zsh prompt — starship for the active line, transient command blocks after.
#
# Active:    ~/path ( branch ⇡2 +1 ~3 ?2 ≡1) ❯ _
# Executed:  12 ~/path
#            > cmd
#            (output)
#            ⏱ <1s
#
# This file owns three things starship cannot do: the numbered transient
# collapse of an accepted line and the ⏱ line printed *after* the output
# (starship's cmd_duration renders in the next prompt, which the collapse would
# overwrite). Everything to the left of ❯ — path, branch, operation, counts —
# is `~/.config/starship.toml`.
#
# Command blocks are copied through kitty's own OSC 133 marks (cmd+up/down to
# pick one, cmd+y to copy it), so nothing parses this text any more. One
# consequence, measured rather than assumed: a copied block ends with the ⏱
# line. Kitty writes its OSC 133 D (command finished) mark from a precmd hook it
# keeps pinned last — `kitty-integration` re-appends itself to precmd_functions
# whenever it is not — so anything a precmd here prints necessarily lands above
# that mark, inside the output region.

# Theme colors are refreshed whenever the theme integration is sourced. Prompt
# state and hook/widget ownership are initialized only once below, so a runtime
# theme switch cannot reset command numbering or disturb Kitty's hook ordering.
# starship reads the palette from the terminal instead, so it needs nothing here.
typeset -g _prompt_muted_color="$prompt_path"
typeset -g _prompt_dir_color="$prompt_dir"
typeset -g _prompt_unstaged_color="$prompt_unstaged"
typeset -g _prompt_arrow_color="$prompt_arrow"

# Render the active line once per prompt and keep the result, rather than
# leaving a live `$(starship prompt)` in PROMPT: the transient collapse swaps
# PROMPT's *value*, and a redraw must not re-run starship with stale state.
# The status/duration/job variables come from starship's own precmd, registered
# ahead of ours below.
_prompt_render_active() {
  if (( $+commands[starship] )); then
    _prompt_active="$(starship prompt --terminal-width="$COLUMNS" \
      --status="${STARSHIP_CMD_STATUS:-0}" \
      --pipestatus="${STARSHIP_PIPE_STATUS[*]:-}" \
      --cmd-duration="${STARSHIP_DURATION:-}" \
      --jobs="${STARSHIP_JOBS_COUNT:-0}")"
  else
    # A machine between `chezmoi apply` and `brew bundle` still gets a prompt.
    _prompt_active="%F{$_prompt_dir_color}%~%f %F{$_prompt_arrow_color}❯%f "
  fi
  _prompt_current="$_prompt_active"
}

# Redraw the accepted line through ZLE itself. Unlike cursor-up escape
# sequences, this remains correct for wrapped and multiline commands.
_prompt_accept_line() {
  emulate -L zsh

  if [[ "$CONTEXT" == start ]]; then
    if [[ "$BUFFER" != *[![:space:]]* ]]; then
      _prompt_current=" "
    else
      (( ++_prompt_cmd_num ))
      _prompt_current="%F{$_prompt_muted_color}${_prompt_cmd_num} %~%f"$'\n'"%F{$_prompt_muted_color}>%f "
    fi
    POSTDISPLAY=""
    zle .reset-prompt
  fi

  # Keep plugin wrappers on the canonical widget intact.
  zle accept-line
  # No redraw and no starship call: the transient form is already painted, and
  # restoring the last rendered line keeps an aborted continuation from leaving
  # the next PS1 transient.
  _prompt_current="$_prompt_active"
}

_prompt_preexec() {
  _PROMPT_CMD_START=$SECONDS
}

_prompt_precmd() {
  emulate -L zsh

  if (( _PROMPT_CMD_START >= 0 )); then
    local elapsed=$(( SECONDS - _PROMPT_CMD_START ))
    _PROMPT_CMD_START=-1
    local time_str="<1s"
    (( elapsed >= 1 )) && time_str="${elapsed}s"
    (( elapsed >= 60 )) && time_str="$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
    print -rP -- "%F{$_prompt_muted_color}⏱ ${time_str}%f"$'\n'
  fi

  _prompt_render_active
}

# Hooks, key bindings, state, and PROMPT ownership are intentionally one-time.
# The file is sourced again by `theme`, after Kitty and autosuggestions have
# wrapped the prompt; re-registering here would corrupt their hook/widget order.
if (( ! ${+_PROMPT_INITIALIZED} )); then
  typeset -gi _PROMPT_INITIALIZED=1
  typeset -gi _prompt_cmd_num=0
  typeset -gi _PROMPT_CMD_START=-1
  typeset -g _prompt_active=""
  typeset -g _prompt_current=""

  autoload -Uz add-zsh-hook

  # starship's init collects exit status, pipe status, duration and job count in
  # its own precmd. It must be registered before ours so those are current by
  # the time _prompt_render_active reads them. Its PROMPT/RPROMPT are discarded
  # below; PROMPT2 (the continuation prompt) is kept.
  (( $+commands[starship] )) && eval "$(starship init zsh)"

  add-zsh-hook preexec _prompt_preexec
  add-zsh-hook precmd _prompt_precmd

  # Use a separate widget instead of replacing canonical `accept-line`, which
  # lets autosuggestions and future plugins keep their wrappers.
  zle -N _prompt_accept_line
  bindkey -M emacs '^M' _prompt_accept_line
  bindkey -M emacs '^J' _prompt_accept_line
  bindkey -M viins '^M' _prompt_accept_line
  bindkey -M viins '^J' _prompt_accept_line
  bindkey -M vicmd '^M' _prompt_accept_line
  bindkey -M vicmd '^J' _prompt_accept_line

  PROMPT='${_prompt_current}'
  RPROMPT=''
  _prompt_render_active
fi
