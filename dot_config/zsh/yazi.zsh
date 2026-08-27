# let Yazi return its chosen directory to the parent shell.
# Yazi shell wrapper - "y" launches yazi, Q inside yazi cds shell to last dir
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
