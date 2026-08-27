#!/usr/bin/env zsh
# install and verify the repository's local quality gates in one command.
# Sets up pre-commit hooks for development
# Usage: ./scripts/setup-hooks.sh
set -e

# Source logging if available (requires chezmoi apply first)
if [[ -f "${HOME}/.config/zsh/00-logging.zsh" ]]; then
  source "${HOME}/.config/zsh/00-logging.zsh"
else
  # Fallback for when logging isn't deployed yet
  info_log() { echo "I [$1] $2"; }
  warn_log() { echo "W [$1] $2" >&2; }
  error_log() { echo "E [$1] $2" >&2; }
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

# Check if pre-commit is available
if ! command -v pre-commit >/dev/null 2>&1; then
  error_log "hooks" "pre-commit not found. Install options:"
  echo "  1. brew install pre-commit"
  echo "  2. pip install pre-commit"
  exit 1
fi

info_log "hooks" "Installing pre-commit hooks..."
pre-commit install

info_log "hooks" "Running hooks on all files to verify setup..."
pre-commit run --all-files

info_log "hooks" "Pre-commit hooks installed!"
echo "   Hooks will run automatically on git commit."
echo "   Run manually: pre-commit run --all-files"
