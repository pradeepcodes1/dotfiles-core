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

On Linux it then makes zsh the login shell if it is not already. Installing the
package does not switch the account to it, so `~/.zshrc` would never be read and
every module here would stay dormant. New sessions pick the change up; existing
ones do not.

Apply then fetches the Yazi plugins and flavors pinned in
`dot_config/yazi/package.toml`. `init.lua` loads the `git` plugin, so Yazi fails
at launch without it. Like the package step, it does nothing when every pinned
package is already deployed.

## If the shell looks unconfigured

No atuin on `^R`, no zoxide, a plain prompt: the account is still on its old
login shell, so `~/.zshrc` was never read and nothing here loaded. Check with

```sh
getent passwd "$USER" | cut -d: -f7
```

and fix it by re-running `./bootstrap.sh`, or by hand with
`chsh -s "$(command -v zsh)"`. Either way it applies to new sessions only — log
out and back in, or open a new terminal.

Two things `dot_config/zsh/plugins.zsh` reaches for have no official repository
build at all — `carapace-bin` and `fzf-tab` — so they are listed apart from the
pacman manifest, in `.chezmoitemplates/packages/aur/common.tmpl`, and installed
with paru or yay. That step is best-effort by design: it warns and skips when no
helper is installed, when the apply is running as root, and when a build fails,
because both call sites are guarded and their absence degrades completion
quietly rather than breaking the shell.

Apply also installs the runtimes pinned in `dot_config/mise/config.toml`.
Activating mise only puts installed tools on PATH, so without this step a
machine has mise and no node, which is enough to break mason's LSP installs. It
gates on `mise ls --missing` and does nothing when every runtime is present.

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
