# Portable dotfiles core

Chezmoi-managed terminal and editor configuration shared across machines.
The minimal Linux profile targets Arch Linux and installs official repository
packages with pacman. Machine-specific applications, identities, secrets and
hotkeys are intentionally outside this repository.

```sh
./bootstrap.sh --dry-run --verbose
./bootstrap.sh
```

Bootstrap installs only missing packages. It does not refresh pacman databases
or perform a full system upgrade; run normal Arch maintenance separately.

Run `scripts/check-public.sh` before every commit. The check scans source paths,
contents and rendered Linux package output for material outside the public
boundary.
