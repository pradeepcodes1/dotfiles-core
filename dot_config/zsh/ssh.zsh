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

# Preserve default SSH completion for the wrapper function
compdef ssh=ssh
