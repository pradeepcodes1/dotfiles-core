# Portable dotfiles core

Chezmoi-managed terminal and editor configuration shared across machines.
The minimal Linux profile targets Arch Linux and installs official repository
packages with pacman. Machine-specific applications, identities, secrets and
hotkeys are intentionally outside this repository.

```sh
./bootstrap.sh --dry-run --verbose
./bootstrap.sh
```

Bootstrap first checks for missing packages. When it finds any, it refreshes
pacman databases, performs a full system upgrade, and installs them in one
transaction. If everything is installed, it does not run pacman.

Apply then fetches the Yazi plugins and flavors pinned in
`dot_config/yazi/package.toml`. `init.lua` loads the `git` plugin, so Yazi fails
at launch without it. Like the package step, it does nothing when every pinned
package is already deployed.

Run `scripts/check-public.sh` before every commit. The check scans source paths,
contents and rendered Linux package output for material outside the public
boundary.

## Kitty

`dot_config/kitty/kitty.conf.tmpl` carries the portable terminal layer: settings,
the full keybinding set, `themes.conf` and the `kitten ssh` configuration. Chords
are spelled `super`, which kitty parses to the same modifier as `cmd`, so one
layout serves macOS and Linux; the macOS-only settings are gated on
`.chezmoi.os`. On a Linux desktop expect the compositor to claim some Super
chords before kitty sees them.

The file ends with `globinclude local.d/*.conf`. That is the extension point for
a private overlay or a single machine — a `map` there overrides the same chord
above it, and having no `local.d` at all is not an error.
