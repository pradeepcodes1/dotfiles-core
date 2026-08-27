# make the shared JSON log searchable without memorizing lnav queries.
# Log viewing utilities for dotfiles JSON logs
# Uses lnav for interactive viewing, filtering, and SQL queries

# Default log file
_DOTFILES_JSONL="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs/dotfiles.jsonl"

# View logs interactively with lnav
# Usage: dotlog [pattern]
dotlog() {
  if [[ ! -f "$_DOTFILES_JSONL" ]]; then
    echo "Log file not found: $_DOTFILES_JSONL"
    return 1
  fi
  if [[ -n "$1" ]]; then
    lnav -c ":filter-in $1" "$_DOTFILES_JSONL"
  else
    lnav "$_DOTFILES_JSONL"
  fi
}

# Show log statistics
dotlog-stats() {
  if [[ ! -f "${1:-$_DOTFILES_JSONL}" ]]; then
    echo "Log file not found: ${1:-$_DOTFILES_JSONL}"
    return 1
  fi
  lnav -n -c ";SELECT log_level AS level, count(*) AS count FROM all_logs GROUP BY log_level ORDER BY count DESC" "${1:-$_DOTFILES_JSONL}"
}

# Search logs by pattern (opens lnav with filter applied)
dotlog-search() {
  if [[ -z "$1" ]]; then
    echo "Usage: dotlog-search <pattern>"
    return 1
  fi
  if [[ ! -f "$_DOTFILES_JSONL" ]]; then
    echo "Log file not found: $_DOTFILES_JSONL"
    return 1
  fi
  lnav -c ":filter-in $1" "$_DOTFILES_JSONL"
}

# Clean old logs
dotlog-clean() {
  local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs"
  local days="${1:-30}"
  echo "Cleaning logs older than $days days..."
  find "$log_dir" -name "*.jsonl*" -mtime +"$days" -delete -print 2>/dev/null
  echo "Done."
}
