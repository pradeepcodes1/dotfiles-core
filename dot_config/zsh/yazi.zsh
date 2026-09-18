# let Yazi return its chosen directory to the parent shell.
# The `y` wrapper launches Yazi; Ctrl+O returns its directory to this shell.
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
		# Make Ctrl+O's directory handoff visible in the completed command block.
		print -r -- "Changing cwd to $cwd"
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
