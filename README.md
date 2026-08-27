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

Run `scripts/check-public.sh` before every commit. The check scans source paths,
contents and rendered Linux package output for material outside the public
boundary.
