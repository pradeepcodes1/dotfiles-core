#!/bin/sh
# Compatibility entry point. The source controller owns planning and apply.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONTROLLER=$SCRIPT_DIR/dot_local/bin/executable_dotfiles

if [ ! -x "$CONTROLLER" ]; then
  echo "Dotfiles controller is missing or not executable: $CONTROLLER" >&2
  exit 1
fi

exec "$CONTROLLER" apply --profile core --core-source "$SCRIPT_DIR" "$@"
