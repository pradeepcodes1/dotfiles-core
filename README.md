# Portable dotfiles core

Chezmoi-managed terminal and editor configuration shared across machines. The
deployed `dotfiles` command is the controller for this core and the active
machine overlay. The minimal Linux profile targets Arch Linux and installs
official repository packages with pacman. Machine-specific applications,
identities, secrets and hotkeys are intentionally outside this repository.

```sh
./dot_local/bin/executable_dotfiles doctor --profile core
./dot_local/bin/executable_dotfiles plan --profile core
./dot_local/bin/executable_dotfiles apply --profile core
```

`bootstrap.sh` remains a compatibility delegate to the same controller. Its
`--dry-run` flag routes to `dotfiles plan`; planning, doctor, and verification
never install packages, clone repositories, change the login shell, enable
services, or write managed targets.

On Arch, apply first checks for missing bootstrap packages. When it finds any,
it refreshes pacman databases, performs a full system upgrade, and installs
them in one transaction. If everything is installed, it does not run pacman.

On Linux it then makes zsh the login shell if it is not already. Installing the
package does not switch the account to it, so `~/.zshrc` would never be read and
every module here would stay dormant. New sessions pick the change up; existing
ones do not.

Apply then fetches the Yazi plugin pinned in
`dot_config/yazi/package.toml`. `init.lua` loads the `git` plugin, so Yazi fails
at launch without it. Like the package step, it does nothing when every pinned
package is already deployed.

## If the shell looks unconfigured

No atuin on `^R`, no zoxide, a plain prompt: the account is still on its old
login shell, so `~/.zshrc` was never read and nothing here loaded. Check with

```sh
getent passwd "$USER" | cut -d: -f7
```

and fix it by running `dotfiles apply`, or by hand with
`chsh -s "$(command -v zsh)"`. Either way it applies to new sessions only — log
out and back in, or open a new terminal.

Two things `dot_config/zsh/plugins.zsh` reaches for have no official repository
build at all — `carapace-bin` and `fzf-tab` — so they are listed apart from the
pacman manifest, in `.chezmoitemplates/packages/aur/common.tmpl`, and installed
with yay or paru. A core-only apply warns and skips when no helper exists. Once
a helper is available, a requested build/install failure fails the apply instead
of leaving completion silently degraded. The `riced-linux` controller profile
bootstraps its audited `yay-bin` revision before applying core, so a fresh
desktop does not hit the missing-helper fallback.

Apply also installs the runtimes pinned in `dot_config/mise/config.toml`.
Activating mise only puts installed tools on PATH, so without this step a
machine has mise and no node, which is enough to break mason's LSP installs. It
gates on `mise ls --missing` and does nothing when every runtime is present.

Run `dotfiles verify` before every commit. It renders active sources, checks
cross-source ownership and removal collisions, validates repository config,
scans Git history for secrets, and invokes `scripts/check-public.sh` for the
public boundary. Install both repositories' hooks with `dotfiles hooks`.

## Controller

After the first apply, `~/.local/bin/dotfiles` supports:

- `doctor` for read-only prerequisite, version, output, and asset checks;
- `plan` for the ordered, non-mutating core/overlay destination diff;
- `apply --skip packages,tools,services` for a controlled layered apply;
- `verify` and `hooks` for repository maintenance;
- `exec --secrets ai|aws -- command ...` to expose credentials only to one
  child process.

Onboarding starts by cloning this public core. The controller then clones and
applies exactly one private overlay:

```sh
git clone https://github.com/pradeepcodes1/dotfiles-core.git ~/.local/share/chezmoi-core
~/.local/share/chezmoi-core/dot_local/bin/executable_dotfiles init personal-mac
# or, on Arch/Niri:
~/.local/share/chezmoi-core/dot_local/bin/executable_dotfiles init riced-linux
```

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

## Themes

Gogh is the only palette source. `theme` downloads its validated JSON
catalog, imports the selected palette into XDG data, and applies generated
colors to Kitty, Zsh, tmux, Neovim, Yazi, fzf, bat/delta, and eza. See
`docs/THEMES.md` for commands, storage paths, and fresh-install behavior.
