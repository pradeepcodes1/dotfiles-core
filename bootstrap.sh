#!/bin/sh
# Bootstrap and apply the portable chezmoi source. Arch Linux uses pacman;
# macOS uses Homebrew only to obtain chezmoi.
set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_NAME=$(uname -s)

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else
    echo "This operation requires root, sudo, or doas" >&2
    exit 1
  fi
}

install_arch_prerequisites() {
  command -v pacman >/dev/null 2>&1 || {
    echo "The minimal Linux profile requires pacman" >&2
    exit 1
  }

  missing=""
  command -v chezmoi >/dev/null 2>&1 || missing="$missing chezmoi"
  command -v git >/dev/null 2>&1 || missing="$missing git"
  command -v zsh >/dev/null 2>&1 || missing="$missing zsh"
  if [ -n "$missing" ]; then
    # shellcheck disable=SC2086
    # Arch does not support partial upgrades. Refresh databases and upgrade the
    # system in the same transaction whenever bootstrap packages are missing.
    run_as_root pacman -Syu --needed --noconfirm -- $missing
  fi
}

install_macos_prerequisites() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    NONINTERACTIVE="${CI:+1}" /bin/bash -c \
      "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ "$(uname -m)" = arm64 ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  command -v chezmoi >/dev/null 2>&1 || brew install chezmoi
}

case "$SYSTEM_NAME" in
  Darwin) install_macos_prerequisites ;;
  Linux) install_arch_prerequisites ;;
  *)
    echo "Unsupported operating system: $SYSTEM_NAME" >&2
    exit 1
    ;;
esac

CHEZMOI_BOOTSTRAP_MODE=1 chezmoi apply --source="$SCRIPT_DIR" "$@"
