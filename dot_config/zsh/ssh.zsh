# preserve Kitty integration for interactive SSH while keeping automation compatible.
# SSH entry points.
#
# Two wrappers live here:
#   ssh()   dispatches plain interactive logins to `kitten ssh`, everything
#           else to the real ssh binary
#   sshm()  runs the sshm host manager with a scoped PATH shim so its
#           connections also go through the kitten
#
# Both are zsh functions, so only interactive shells see them. Scripts, cron,
# git, rsync and agent sessions get the real ssh untouched. `command ssh` is the
# escape hatch from an interactive shell.

# Should this invocation go through the ssh kitten?
#
# All of these have to hold:
#   - we are in a kitty window: outside one the kitten exits with
#     "The SSH kitten is meant to run inside a kitty window"
#   - we are not inside tmux: the kitten is known to hang or leak its escape
#     sequences into the shell under tmux 3.3+ (kovidgoyal/kitty#5240, #5227)
#   - stdout is a tty
#   - the invocation is exactly `ssh <host>`: with a remote command the kitten
#     skips -t, and its bootstrap still wants to read setup data from the tty
#   - the kitten is actually installed
_ssh_use_kitten() {
  [[ -n $KITTY_WINDOW_ID ]] || return 1
  [[ -z $TMUX ]] || return 1
  [[ -t 1 ]] || return 1
  (( $# == 1 )) || return 1
  [[ $1 != -* ]] || return 1
  (( $+commands[kitten] )) || return 1
}

ssh() {
  if _ssh_use_kitten "$@"; then
    kitten ssh "$@"
    return
  fi

  # Plain path. Inside local tmux, surface the target host in the status bar
  # (status-right renders #{@ssh_host}); this is also the path taken when the
  # kitten is skipped because of tmux, so the two stay consistent.
  local host
  host=$(command ssh -G "$@" 2>/dev/null | awk '/^hostname /{print $2}')
  [[ -z "$host" ]] && host="${@: -1}"

  [[ -n "$TMUX" ]] && tmux set -p @ssh_host "$host"
  command ssh "$@"
  [[ -n "$TMUX" ]] && tmux set -p -u @ssh_host
}

# sshm host manager.
#
# -c pins the writable host list. sshm writes new and edited hosts to whatever
# -c names, and ~/.ssh/config itself is chezmoi-managed — pointing sshm at it
# would mean every `sshm add` gets reverted by the next `dotfiles apply`.
#
# The PATH prefix is what makes sshm's connections use the kitten: sshm looks up
# `ssh` on PATH and execs it, with no setting to override the binary. The shim
# removes itself from PATH and falls back to real ssh outside kitty. Scoped to
# this one invocation so nothing else on the system sees it.
sshm() {
  PATH="$HOME/.config/sshm/shim:$PATH" \
    command sshm -c "$HOME/.ssh/config.d/hosts.conf" "$@"
}

# Preserve default SSH completion for the wrapper function.
#
# Guarded because compinit only runs in shells that will draw a prompt (see
# ~/.zshrc): the one-shot `zsh -ic` shells Kitty launches -- Ctrl+M's
# sshm-window among them, defined just below -- reach here with no compdef.
(( $+functions[compdef] )) && compdef ssh=ssh

# sshm in a Kitty window of its own — what Ctrl+M launches.
#
# Kitty closes the window the moment this returns, which is right for a
# finished session or a dismissed picker but wrong for a connection that never
# came up: "Connection refused" or "Permission denied" is on screen for the
# instant before the window disappears. Hold the window open so the error can
# actually be read.
#
# What we cannot use to detect that is sshm's own exit status: it exits 0
# whether the ssh it launched connected or failed. The shim
# (dot_config/sshm/shim/executable_ssh) is the only thing that sees the real
# status, so
# it appends each connection's status to SSHM_STATUS_FILE and we read the
# last line back here. An empty file means the picker was dismissed without
# connecting to anything.
#
# 130 is Ctrl+C on either side — the user has already decided to leave and has
# nothing to read.
sshm-window() {
  local status_file
  status_file=$(mktemp "${TMPDIR:-/tmp}/sshm-status.XXXXXX") || return 1

  SSHM_STATUS_FILE=$status_file sshm "$@"
  local ret=$?

  local ssh_ret
  ssh_ret=$(tail -n 1 -- "$status_file" 2>/dev/null)
  rm -f -- "$status_file"

  local reason
  if [[ $ssh_ret == <-> ]] && (( ssh_ret != 0 && ssh_ret != 130 )); then
    reason="ssh exited with status $ssh_ret"
  elif (( ret != 0 && ret != 130 )); then
    reason="sshm exited with status $ret"
  else
    return $ret
  fi

  print -u2
  print -u2 -- "$reason. Press any key to close this window."

  # Whatever was typed while the connection was failing is still buffered —
  # the Enter that picked the host in sshm's list arrives here when ssh gives
  # up immediately — and would dismiss this prompt before it could be read.
  # Discard it, then wait for a key the user actually meant to press.
  while read -t 0 -k 1 -s; do :; done
  read -k 1 -s
  return $ret
}

# Mark a Kitty window whose shell has not run anything yet.
#
# Ctrl+M normally opens sshm in a new tab so the calling shell keeps its
# scrollback — but a shell that has run nothing has no scrollback worth
# keeping, and the extra tab is pure clutter. kitty.conf pairs
# `map --when-focus-on var:shell_fresh` with an overlay variant of the same
# binding, so an untouched window gets taken over in place instead.
#
# The mark is set from precmd rather than at startup so the `zsh -ic ...`
# shells Kitty launches for its own popups never claim to be fresh: they run
# one command and exit without ever drawing a prompt. It is dropped by preexec
# the moment a real command runs, and each hook does its work only once.
#
# MQ== is base64 "1"; only the variable's presence is ever tested, and sending
# the escape with no value deletes it. Both hooks return the status they were
# entered with, so a later precmd hook still sees the exit code of the command
# that just finished.
#
# _KITTY_SHELL_FRESH runs 0 (not marked yet) -> 1 (marked) -> 2 (cleared), so
# the prompt drawn after the first command does not mark the window fresh all
# over again. Ctrl+L puts it back to 1 (dot_config/zsh/basics.zsh.tmpl): that
# widget throws away the screen, the retained scrollback and the command
# numbering, which leaves nothing worth protecting.
typeset -gi _KITTY_SHELL_FRESH=0

# Write to $TTY rather than stdout: Ctrl+L calls _kitty_set_fresh_shell from a
# ZLE widget, where stdout is not the terminal.
_kitty_set_fresh_shell() {
  [[ -n $KITTY_WINDOW_ID ]] || return 0
  _KITTY_SHELL_FRESH=1
  builtin print -rn -- $'\e]1337;SetUserVar=shell_fresh=MQ==\a' >"${TTY:-/dev/tty}"
}

_kitty_mark_fresh_shell() {
  local ret=$?
  (( _KITTY_SHELL_FRESH == 0 )) && _kitty_set_fresh_shell
  return $ret
}

_kitty_clear_fresh_shell() {
  local ret=$?
  if (( _KITTY_SHELL_FRESH == 1 )); then
    _KITTY_SHELL_FRESH=2
    builtin print -rn -- $'\e]1337;SetUserVar=shell_fresh\a' >"${TTY:-/dev/tty}"
  fi
  return $ret
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _kitty_mark_fresh_shell
add-zsh-hook preexec _kitty_clear_fresh_shell
