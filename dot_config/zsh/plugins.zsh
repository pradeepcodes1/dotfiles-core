# initialize optional shell enhancements only when their binaries are available.
# Plugin initialization

# Make `cd` zoxide-aware; its chpwd hook records each directory exactly once.
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
  alias zi=cdi
fi
# Initialize atuin
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# navi cheatsheets, replacing tldr. Its widget binds ^G: on an empty line it
# opens the cheatsheet browser, otherwise it looks up what is already typed and
# replaces the line with the chosen snippet. ^G was zsh's default `send-break`,
# which ^C already covers. Eager rather than lazy-loaded like other optional
# modules: `navi widget zsh` is a ~3ms static print, and a lazy stub cannot
# install a keybinding without being invoked first anyway.
command -v navi &>/dev/null && eval "$(navi widget zsh)"

# Carapace configuration
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
if command -v carapace &>/dev/null; then
  source <(carapace _carapace zsh)
fi

# Standard Zsh matching rules - helps with prefix handling and fuzzy matching
# This allows fzf-tab to correctly identify path prefixes (like 'dir/') vs search queries
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Source a packaged zsh plugin from Homebrew or Arch's shared-data directory.
_source_zsh_plugin() {
  local name=$1 file=$2 root
  local -a roots

  [[ -n $HOMEBREW_PREFIX ]] && roots+=("$HOMEBREW_PREFIX/share")
  if (( $+commands[brew] )); then
    roots+=("$(brew --prefix)/share")
  fi
  roots+=(/usr/share/zsh/plugins)

  for root in "${roots[@]}"; do
    if [[ -f "$root/$name/$file" ]]; then
      source "$root/$name/$file"
      return
    fi
  done
}

# fzf-tab configuration
_source_zsh_plugin fzf-tab fzf-tab.zsh

# Configure fzf-tab query-string to use only 'prefix' (fixes carapace subdirectory issue)
# Default is 'prefix input first', but 'input' causes 'folder/' to be used as search query
# With carapace, using only 'prefix' prevents the typed path from filtering results
zstyle ':fzf-tab:*' query-string prefix

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# Smart preview: only show for file/directory groups
zstyle ':fzf-tab:complete:*:*' fzf-preview '[[ "$group" == *"files"* || "$group" == *"directories"* || "$group" == *"directory"* ]] && {
  local target=${realpath:-$word}
  target="${target% }"

  if [[ -d "$target" ]]; then
    eza -1 --icons --color=always "$target" 2>/dev/null
  elif [[ -f "$target" ]]; then
    if file --mime "$target" 2>/dev/null | grep -q "charset=binary"; then
      echo "📦 Binary file: $(file -b "$target")"
    else
      bat --paging=never --color=always --style=numbers "$target" 2>/dev/null
    fi
  fi
} || :'

# Hide preview window border when no content (threshold < 1 line)
# Set overall completion window size to 60% of screen height
zstyle ':fzf-tab:complete:*:*' fzf-flags --height=60% --preview-window=down:30%:wrap:border-top:~0

# switch group using < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Ctrl+U / Ctrl+D scroll the candidate list half a page, matching vi and the
# same pair in `tmux/relative-copy-mode.py`. fzf-tab *appends* `fzf-bindings`
# to its own defaults (tab:down, btab:up, change:top, ctrl-space:toggle,
# bspace/ctrl-h:backward-delete-char) instead of replacing them, so those and
# the switch-group keys are untouched. This does override two fzf defaults:
# ctrl-u was unix-line-discard (clearing the query), and ctrl-d was
# delete-char/eof, which closes fzf outright when the query is empty.
# Not the arrow keys: macOS claims Ctrl+Up/Ctrl+Down for Mission Control and
# Application Windows (symbolic hotkeys 32/33), so those never reach kitty.
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-u:half-page-up' 'ctrl-d:half-page-down'

# zsh-autosuggestions configuration
_source_zsh_plugin zsh-autosuggestions zsh-autosuggestions.zsh

# zsh-syntax-highlighting configuration (must be last)
_source_zsh_plugin zsh-syntax-highlighting zsh-syntax-highlighting.zsh
